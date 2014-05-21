# trunk.cocoapods.org


[![Build Status](https://img.shields.io/travis/CocoaPods/trunk.cocoapods.org/master.svg?style=flat)](https://travis-ci.org/CocoaPods/trunk.cocoapods.org)


Available under the MIT license.

## Installation

1. Create a testing sandbox repository on GitHub and, from the CocoaPods specification repository,
   add the [`Gemfile`](https://raw.github.com/CocoaPods/Specs/master/Gemfile) and
   [`Rakefile`](https://raw.github.com/CocoaPods/Specs/master/Rakefile) files.

2. Install PostgreSQL. (On OS X you can use the [Postgres App](http://postgresapp.com).)

3. Install the dependencies:

        $ rake bootstrap

4. Create and migrate the databases for the various environments:

        $ rake db:bootstrap RACK_ENV=test
        $ rake db:bootstrap RACK_ENV=development

5. Test whether or not a pod sends correctly

        $ ./bin/test-push localhost:4567 spec/fixtures/AFNetworking.podspec

## Usage

To start a development server run the following command, replacing the
environment variables with your GitHub credentials, a GitHub testing sandbox
repository, and a SHA hashed version of the password for the admin area (in
this example the password is ‘secret’):

    env RACK_ENV=development \
        GH_USERNAME=alloy GH_EMAIL=user@example.com GH_TOKEN=secret GH_REPO=alloy/trunk.cocoapods.org-test \
        TRUNK_APP_PUSH_ALLOWED=true TRUNK_APP_ADMIN_PASSWORD=2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b \
        rake serve

Optional environment variables are:

* `RACK_ENV`: Can be test, development, or production.
* `DATABASE_URL`: The URL to the PostgreSQL database.

## Webhook

The webhook sends messages to other services when events in trunk happen.

These events trigger the webhook and send a message.

* Successful creation of a Commit: `{ type: 'commit', created_at: <date>, data_url: <URL> }`

Environment variables are:

* `OUTGOING_HOOK_PATH`: The garbled path used at the end of `<schema>://<domain>/hooks/trunk/<OUTGOING_HOOK_PATH>`.
* `WEBHOOKS_ENABLED`: If set to `true`, the webhook is enabled.

### Programmatic usage

Trigger a message explicitly:

    Webhook.call(message)

Change the webhook service URLs:

    Webhook.urls = [...]

Check if it is enabled:

    Webhook.enabled?