source 'https://rubygems.org'
ruby File.read(File.join(File.dirname(__FILE__), '.ruby-version')).chomp

gem 'cocoapods-core', '~> 1.11'
gem 'dalli', '~> 3.2.8'
gem 'json'
gem 'mail', '~> 2.8'
gem 'newrelic_rpm'
gem 'will_paginate'
gem 'pg', '~> 1.5'
gem 'rack-attack', '~> 6.7.0'

gem 'rack-ssl'
gem 'rfc-822'
gem 'sass'
gem 'sequel', '~> 5.85'

gem 'sinatra', '~> 4.0'
gem 'sinatra-twitter-bootstrap'
gem 'slim'

group :rake do
  gem 'rake'
  gem 'terminal-table'
end

group :development, :production do
  gem 'puma'
end

group :development do
  gem 'foreman'
  gem 'kicker'
  gem 'saga'

  # Only needed for importing existing spec repo data into DB.
  # gem 'rugged'

  gem 'pry'

  gem 'sinatra-contrib'
end

group :test do
  gem 'bacon'
  gem 'mocha-on-bacon'
  gem 'nokogiri', '~> 1.16'
  gem 'prettybacon'
  gem 'rack-test'
  gem 'rubocop'
  gem 'rubocop-performance'
end

gem 'rubocop-sequel', '~> 0.3.4'

gem 'rubocop-rake', '~> 0.6.0'
