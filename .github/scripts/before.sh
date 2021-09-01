#!/bin/bash

git clone https://github.com/CocoaPods/Humus.git
cd Humus
bundle install
RACK_ENV=test bundle exec rake db:bootstrap
