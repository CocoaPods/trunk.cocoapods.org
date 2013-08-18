source 'https://rubygems.org'
ruby '2.0.0'

gem 'activesupport'
gem 'cocoapods-core', :git => 'git://github.com/CocoaPods/Core.git'
gem 'mail'
gem 'nap'
gem 'pg'
gem 'rack-ssl'
gem 'rake'
gem 'safe_yaml'
gem 'sequel'
gem 'sinatra'
gem 'sinatra-twitter-bootstrap'

group :development, :production do
  gem 'foreman'
  gem 'thin'
end

group :production do
  gem 'newrelic_rpm'
end

group :development do
  gem 'kicker', :git => 'https://github.com/alloy/kicker.git', :branch => '3.0.0'
  gem 'saga'
  gem 'terminal-table'
end

group :test do
  gem 'bacon'
  gem 'mocha-on-bacon'
  gem 'rack-test'
end
