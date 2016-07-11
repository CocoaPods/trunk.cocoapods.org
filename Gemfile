source 'https://rubygems.org'
ruby File.read(File.join(File.dirname(__FILE__), '.ruby-version')).chomp

gem 'activesupport', '< 5'

gem 'cocoapods-core', '>= 1.0.0.beta.3'
gem 'tobias-sinatra-url-for'
gem 'json', '~> 1.8'
gem 'mail'
gem 'newrelic_rpm'
gem 'peiji-san', :git => 'https://github.com/alloy/peiji-san.git'
gem 'pg'
gem 'rack-ssl'
gem 'rack-attack', '~> 4.3.1'
gem 'dalli', '~> 2.7.5'
gem 'rfc-822'
gem 'sequel'
gem 'sinatra'
gem 'sinatra-twitter-bootstrap'
gem 'slim', '< 2.0'
gem 'sass'

group :rake do
  gem 'rake'
  gem 'terminal-table'
end

group :development, :production do
  gem 'foreman'
  gem 'thin'
end

group :development do
  gem 'kicker'
  gem 'saga'

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
  gem 'rubocop', '0.34.2'
end
