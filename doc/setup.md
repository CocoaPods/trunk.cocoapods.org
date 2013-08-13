# Setting up the application for development

## Install required gems

   gem install bundler
   bundle install

## Create your own repository with CocoaPods

Head over to Eloy's test repository and fork it to your account:

    https://github.com/alloy/push.cocoapods.org-test

Now configure the whole thing in your app server's environment; for example, here is my .powenv:

    export DATABASE_URL=postgres://localhost/push_cocoapods_org_dev
    export GH_USERNAME=manfred
    export GH_PASSWORD=secret
    export GH_REPO=manfred/push.cocoapods.org-test

Replace the username, password, and repo by your own. Please. Don't even…

Export the configured stuff in your env for convenience:

    source .powenv

## Create development and test databases

    createdb --encoding=utf-8 push_cocoapods_org_dev
    createdb --encoding=utf-8 push_cocoapods_org_test

    sequel -m db/migrations $DATABASE_URL