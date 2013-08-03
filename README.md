# push.cocoapods.org

Available under the MIT license.

## Installation

1. Install PostgreSQL.

2. Install the dependencies:

        rake bootstrap

3. Create a PostgreSQL database:

        createdb push_cocoapods_org_dev -E UTF8

## Usage

To start a development server run the following command, replacing the environment variables with
your GitHub credentials, a GitHub testing sandbox repository, and your Travis-CI API token:

    env GH_USERNAME=alloy GH_PASSWORD=secret GH_REPO=alloy/push.cocoapods.org-test TRAVIS_API_TOKEN=secret rake serve

