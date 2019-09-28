# Description:
#   Ping Slack teams via text message using voip.ms
#
# Configuration:
#   HUBOT_DOORBELL_PHONE_NUMBER
#   HUBOT_DOORBELL_CHANNEL_OPEN
#   HUBOT_DOORBELL_CHANNEL_PRIV
#   HUBOT_VOIPMS_API_PROXY_URL
#   HUBOT_VOIPMS_API_USER
#   HUBOT_VOIPMS_API_PASS
#
# Notes:
#   To use this script, you must:
#   - Buy an SMS-enabled VOIP phone number (aka your DID) from voip.ms. (The
#     cost is as low as USD$0.85/month.)
#   - Set up that DID's "SMS URL Callback" to point to
#     https://example-bot.herokuapp.com/doorbell?... (using whatever your base url is
#     for your hubot).
#   - Full instructions: https://github.com/CivicTechTO/hubot-toby/wiki/Script:-SMS-Doorbell
#
# Commands:
#   None
#
# Author:
#   patcon@github

emoji = require 'node-emoji'
querystring = require 'querystring'
ProxyAgent = require 'proxy-agent'

config =
  phone_number: process.env.HUBOT_DOORBELL_PHONE_NUMBER or '555-555-5555'
  # You will need the channel IDs (ie. C4SHX39B2),
  # not the human-readable name (ie. #my-channel).
  # You can get this from the browser url:
  #                                       /THIS PART/ might be ignorable trailing part
  # https://app.slack.com/client/T04TJ34BU/C4SHX39B2/thread/C4SHX39B2-1568881564.072800
  channel_open: process.env.HUBOT_DOORBELL_CHANNEL_OPEN
  channel_priv: process.env.HUBOT_DOORBELL_CHANNEL_PRIV
  voipms_user: process.env.HUBOT_VOIPMS_API_USER
  voipms_pass: process.env.HUBOT_VOIPMS_API_PASS
  # Because the Voip.ms API can only be accessed from an unchanging static IP,
  # we need to use a proxy with a static IP. For this, we can use Fixie, a heroku add-on.
  # It gets 500 free connections/month. This is more than I will need, so I'll share mine as default.
  # You may need your own if this becomes overused and I have to make it private.
  # See here for setup instructions on creating your own proxy url:
  #   https://elements.heroku.com/addons/fixie
  proxy_url: process.env.HUBOT_VOIPMS_API_PROXY_URL || 'http://fixie:HZOy3W1xBMA76KC@velodrome.usefixie.com:80'

module.exports = (robot) ->
  web = robot.adapter.client.web

  robot.router.get '/doorbell', (req, res) ->
    sms_msg = req.query.message
    from = req.query.from

    # Add dashes so that Slack can add dynamic link for calling on mobile app.
    humanizePhone = (phone_raw) ->
      phone_re = /(\d+?)(\d{3})(\d{4})$/
      return phone_raw.match(phone_re)[1..3].join('-')

    extra = if isSmsSendingConfigured() then ", and I'll forward it to the texter" else ''

    if config.channel_open
      bot_msg_open = """
      @here there's someone at the door! They texted:
      > #{sms_msg}

      :raising_hand: Please use any reaction emoji if you're heading to help#{extra}!

      (This message was created by texting our doorbell at #{config.phone_number}. The sender's number was shared in `#organizing-priv`.)
      """
      robot.adapter.client.web.chat.postMessage(config.channel_open, bot_msg_open, {
        as_user: true,
        parse: 'full',
        attachments: [
          {
            fallback: '',
            callback_id: 'hubot_doorbell_caller_' + from
          }
        ]
      })

    if config.channel_priv
      bot_msg_priv = """
      Here's the phone number that texted our doorbell: #{humanizePhone(from)}
      (Full context in #organizing-open.)
      """
      robot.adapter.client.web.chat.postMessage(config.channel_priv, bot_msg_priv, {
        as_user: true,
        parse: 'full',
      })

    # Voip.ms expects this on successful messages, for their "callback retry"
    # feature to work.
    res.send 'ok'

  robot.hearReaction (res) ->
    if not isSmsSendingConfigured()
      return

    if not reactingToBot(res)
      return

    if res.message.type != 'added'
      return

    reacted_msg = res.message.item
    reacting_user = res.message.user.name
    reacting_emoji = res.message.reaction

    robot.logger.debug "Reacting to bot message: #{reacted_msg.ts}"

    web.conversations.history reacted_msg.channel, {latest: reacted_msg.ts, limit: 1, inclusive: true}
      .then (resp) ->
        reacted_message = resp.messages[0]
        if reacted_message.attachments? and reacted_message.attachments[0].callback_id.startsWith 'hubot_doorbell'
          robot.logger.debug "Reacting to doorbell bot message: #{reacting_emoji}"

          dest_phone = reacted_message.attachments[0].callback_id.replace 'hubot_doorbell_caller_', ''
          sms_auto_response = "Auto-response: #{reacting_user} acknowledged your message with a :#{reacting_emoji}: emoji"
          sms_auto_response = emoji.emojify(sms_auto_response)
          params =
            api_username: config.voipms_user
            api_password: config.voipms_pass
            method: 'sendSMS'
            # TODO: Don't hardcode our own number!
            did: '6478122649'
            dst: dest_phone
            message: sms_auto_response

          qs = querystring.stringify(params)
          robot.http('https://voip.ms/api/v1/rest.php?'+qs, {agent: new ProxyAgent config.proxy_url})
            .get() (err, res, body) ->
              data = JSON.parse body
              if data.status isnt 'success'
                # TODO: Better error surfacings in Slack
                robot.logger.warning "Something went wrong with SMS"
                return

              slack_response = "Sent this SMS to texter:\n> #{sms_auto_response}"
              robot.adapter.client.web.chat.postMessage(reacted_msg.channel, slack_response, {thread_ts: reacted_msg.ts, as_user: true})
              return

  reactingToBot = (res) ->
    return res.robot.name == res.message.item_user.name

  isSmsSendingConfigured = ->
    return config.voipms_user? and config.voipms_pass?
