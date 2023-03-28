require 'bundler/setup'

$:.unshift File.expand_path('..', __FILE__)
require 'app/controllers/app_controller'

if ENV['RACK_ENV'] != 'development'
  require 'rack/attack'
  require_relative 'config/rack_attack'

  use Rack::Attack
end

#use Rack::Throttle::Hourly,   max: 100 # requests
#use Rack::Throttle::Interval, min: 5.0 # seconds

unless ENV['TRUNK_APP_LOG_TO_STDOUT']
  # Redirect sinatra output to log file.
  STDOUT.reopen(TRUNK_APP_LOG_FILE)
  STDERR.reopen(TRUNK_APP_LOG_FILE)
end

warn :run

run Pod::TrunkApp::App

warn :ran