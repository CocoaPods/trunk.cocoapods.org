# trunk.cocoapods.org

Available under the MIT license.

## Installation

1. Create a testing sandbox repository on GitHub and, from the CocoaPods specification repository,
   add the [`Gemfile`](https://raw.github.com/CocoaPods/Specs/master/Gemfile) and
   [`Rakefile`](https://raw.github.com/CocoaPods/Specs/master/Rakefile) files.

2. Install PostgreSQL. (On OS X you can use the [Postgres App](http://postgresapp.com).)

3. Install the dependencies:

        $ rake bootstrap

4. Create the PostgreSQL databases for the various environments:

        $ createdb -h localhost trunk_cocoapods_org_test -E UTF8
        $ createdb -h localhost trunk_cocoapods_org_development -E UTF8
        $ createdb -h localhost trunk_cocoapods_org_production -E UTF8

5. Migrate the database(s):

        $ rake db:migrate RACK_ENV=test
        $ rake db:migrate RACK_ENV=development
        $ rake db:migrate RACK_ENV=production

6. Test whether or not a pod sends correctly

        $ ./bin/test-push localhost:4567 spec/fixtures/AFNetworking.podspec

## Usage

To start a development server run the following command, replacing the environment variables with
your GitHub credentials, a GitHub testing sandbox repository, and a SHA hashed version of the
password for the admin area (in this example the password is ‘secret’):

    env RACK_ENV=development \
        GH_USERNAME=alloy GH_EMAIL=user@example.com GH_TOKEN=secret GH_REPO=alloy/trunk.cocoapods.org-test \
        TRUNK_APP_PUSH_ALLOWED=1 TRUNK_APP_ADMIN_PASSWORD=2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b \
        rake serve

Optional environment variables are:

* `RACK_ENV`: Can be test, development, or production.
* `DATABASE_URL`: The URL to the PostgreSQL database.
