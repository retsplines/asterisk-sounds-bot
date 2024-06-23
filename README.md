# [`asterisk-sounds-bot`](https://botsin.space/@asterisksounds)

A silly bot that posts [sounds](https://downloads.asterisk.org/pub/telephony/sounds/) from the [Asterisk PBX](https://www.asterisk.org/) to the [fediverse](https://botsin.space/@asterisksounds).

## Operation

An AWS Lambda function (`src/main.py`) reads the list of available sounds from `data/sound-list.txt`, selects one and posts it to Fedi.

The Lambda function is invoked by an hourly Amazon EventBridge schedule.

Configuration for the Lambda function (the S3 bucket location, Mastodon credentials, and other parameters) is supplied via environment variables.

The list of available sounds (`data/sound-list.txt`) is committed, and reflects the sounds available in a pre-created S3 bucket. This file and the associated sound files compilation is generated by `build-sound-list.sh`.

## Complaints

If this bot misbehaves, or otherwise upsets you in some way, please reach out through GitHub [Issues](https://github.com/retsplines/asterisk-sounds-bot/issues).

## Licenses

The bot source code contained in this repository is hereby released under the [MIT](./LICENSE.md) license.

The [sound files](https://downloads.asterisk.org/pub/telephony/sounds/) posted by the bot are covered by the [Creative Commons Attribution-Share Alike 3.0](https://creativecommons.org/licenses/by-sa/3.0/us/) license according the the [Asterisk documentation](https://docs.asterisk.org/About-the-Project/License-Information/Voice-Prompts-and-Music-on-Hold-License/).
