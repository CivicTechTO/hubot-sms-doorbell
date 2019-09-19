# hubot-sms-doorbell

Ping Slack teams via text message using voip.ms

Do you organize an event-based community (e.g. meetup), and wish for
any easy way to let confused people get access to the venue? This will
help you with that!

We use this script as a doorbell for meetups, so that all organizers can
easily take responsibility for answering and dealing with issues.

> No more sharing personal phone numbers on the internet or public signage!
>
> No more coordinating whose number to use!
>
> No more  having responsibility fall only on one person!

This chatbot script works through voip.ms, a platform that offers
super-cheap internet numbers (~$0.85/month) that include SMS messages.
You'll set up it up to notify your Slack team whenever

It drops the message into a public channel, and the phone number itself
into a private channel, to protect privacy of texters.

Optionally, if Voip.ms API access is configured, then reaction emoji
will be relayed back to the texter to give them assurance they've been
noticed.

See [`src/sms-doorbell.coffee`](src/sms-doorbell.coffee) for technical documentation.

For **setup documentation** (including voip.ms), see [the SMS Doorbell wiki page](https://github.com/CivicTechTO/hubot-toby/wiki/Script:-SMS-Doorbell)

## Installation

In hubot project repo, run:

`npm install civictechto/hubot-sms-doorbell#master --save`

Then add **hubot-sms-doorbell** to your `external-scripts.json`:

```json
[
  "hubot-sms-doorbell"
]
```

## Sample Interaction

1. Someone texts "help! I'm locked out" to Voip.ms doorbell number from 555-555-5555
2. Bot drops messages in Slack channels:
    - Relays "help! I'm locked out" in `#organizing-open`
    - Relays phone number 555-555-55555 in `#organizing-priv` (optional)
3. Slack users are encouraged to add reaction to message in `#organizing-open`
    - For sake of example, a user named "dilini" reacts
4. Both the texter at 555-555-5555 and the Slack thread receive a confirmation that
   "dilini has acknowledged your message with a :rocket: emoji"

```
chatbot>> Someone rang the doorbell! "help! I'm locked out" (pls react and we'll fwd to texter)
dilini>> *reacts with :rocket:*
chatbot>> *in thread* We've sent this to the texter: "dilini has acknowledged your message with a :rocket: emoj"
```

## NPM Module

https://www.npmjs.com/package/hubot-sms-doorbell (doesn't yet exist)
