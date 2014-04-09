# Authorization

We'll look at authorization from the client standpoint. The object of the interaction is to get a valid and verified session token.

## Very first token

We start by posting our personal data. The `name` attribute is optional.

    POST /register
    Content-Type: text/yaml; charset=utf-8

    ---
    email: jessi@example.com
    name: Jessi McLean

When successful this returns a `201 Created` with the session information in the body:

    ---
    token: as43iu45df89oi
    valid_until: 2013-08-14 16:43:40.679972000 +02:00
    verified: false

If something goes wrong you get a `422` with a YAML error body or a `500` when everything is broken.

You can now store this token and possibly the other information. Note that you will not be able to authenticate with it because it's not verified yet.

Ask your command line pilot to check their e-mail. They should receive and e-mail with a confirm link. Once they click the link the token will be verified and usable.

You can authenticate by sending the token in an Authorization header:

    POST /pods
    Authorization: Token as43iu45df89oi

If the token is no longer valid or when it's wrong, you will get a `401 Unauthenticated`.

**NOTE**: The implementation could return a `X-Token-State` header with the `401` to indicate what's going on. Possible values could be `valid`, `expired`, `unverified`, or `unknown`.

## Getting a new token

When you get a `401` with a previously valid token, when you know it's no longer valid, or when you forgot it somehow you can get a new one with the exact same process as before.

**NOTE**: The implementation could use a slightly different verification email. First token would be something like ‘Please confirm your registration with CocoaPods’, and subsequent emails could be ‘Please confirm your CocoaPods session’.

## Optional extras

You could let people verify their session through an OAuth dance:

    POST /register
    Content-Type: text/yaml; charset=utf-8

    ---
    github: Manfred

Which responds with:

    ---
    token: as43iu45df89oi
    valid_until: 2013-08-14 16:43:40.679972000 +02:00
    verified: false
    verify_at: https://push.cocoapods.org/sessions/as43iu45df89oi/verify
