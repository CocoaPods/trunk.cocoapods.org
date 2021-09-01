#!/bin/bash

git clone --branch bump_ruby https://github.com/CocoaPods/Humus.git
cd Humus
bundle install
RACK_ENV=test bundle exec rake db:bootstrap
