require 'bundler/setup'

ROOT = File.expand_path('..', __FILE__)
$:.unshift ROOT
require 'app/controllers/app'

#use Rack::Throttle::Hourly,   max: 100 # requests
#use Rack::Throttle::Interval, min: 5.0 # seconds

run Pod::PushApp::App
