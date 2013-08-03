require 'bundler/setup'

$:.unshift File.expand_path('..', __FILE__)
require 'app/controllers/app'

#use Rack::Throttle::Hourly,   max: 100 # requests
#use Rack::Throttle::Interval, min: 5.0 # seconds

# Redirect sinatra output to log file.
STDOUT.reopen(PUSH_LOG_FILE)
STDERR.reopen(PUSH_LOG_FILE)

run Pod::PushApp::App
