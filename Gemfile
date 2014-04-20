source 'https://rubygems.org'
ruby '2.1.1'

gem 'activesupport'
gem 'cocoapods-core', :git => 'https://github.com/CocoaPods/Core.git'
gem 'tobias-sinatra-url-for'
gem 'json', '~> 1.8'
gem 'mail'
gem 'nap', :git => 'https://github.com/alloy/nap.git', :branch => 'error'
gem 'newrelic_rpm'
gem 'peiji-san', :git => 'https://github.com/alloy/peiji-san.git'
gem 'pg'
gem 'rack-ssl'
gem 'rake'
gem 'rfc-822'
gem 'sequel'
gem 'sinatra'
gem 'sinatra-twitter-bootstrap'
gem 'slim', '< 2.0'
gem 'sass'

group :development, :production do
  gem 'foreman'
  gem 'thin'
end

group :development do
  gem 'kicker'
  gem 'saga'
  gem 'terminal-table'

  # Only needed for importing existing spec repo data into DB.
  gem 'rugged'

  gem 'sinatra-contrib'
end

group :test do
  gem 'bacon'
  gem 'mocha-on-bacon'
  gem 'nokogiri'
  gem 'prettybacon'
  gem 'rack-test'
  gem 'rubocop'
end
