source 'https://rubygems.org'
ruby '2.0.0'

gem 'activesupport'
gem 'cocoapods-core'
gem 'json', '~> 1.8'
gem 'mail'
gem 'nap'
gem 'newrelic_rpm'
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
