# Security Policy

## Supported versions

The latest release is the supported one. LocalFlow is a single-developer
project; fixes land in a new release rather than in backports.

| Version | Supported |
| ------- | --------- |
| 1.2.x   | Yes       |
| < 1.2   | No        |

## Reporting a vulnerability

Please report privately through GitHub's
[security advisory form](https://github.com/therealone00/LocalFlow/security/advisories/new)
rather than opening a public issue.

Include what an attacker could achieve, how to reproduce it, and the version and
macOS release you saw it on. You can expect a first response within a week.

## What is in scope

LocalFlow holds two capabilities that matter here:

- **Accessibility access**, used to read the text around your cursor and to type
  into other applications
- **Microphone access**, used to record while you hold the hotkey

Anything that abuses those — reading from secure or password fields, retaining
audio beyond a transcription, writing transcripts somewhere unexpected, or
escalating the app's reach into other applications — is in scope, as is any
outbound network traffic other than an explicit, user-initiated model download.

## Licensing is not a security boundary

The Pro license check is an Ed25519 signature verified locally. Being able to
patch it out of your own build is not a vulnerability — the source is public and
that is expected. What *is* worth reporting: a way to forge a signature that the
shipping public key accepts, or anything that makes the licensing code leak data
off the machine.

## What is not a vulnerability

- The Gatekeeper prompt on first launch. The app is signed but not notarised;
  this is expected and is documented on the website.
- Locally stored dictation history. It is on by default, it is plain JSON in
  Application Support, and it can be turned off and cleared in Settings ›
  Privacy. Anyone who can read that file can already read your home directory.
