$:.unshift(File.expand_path('../../', __FILE__))
ENV['RACK_ENV'] ||= 'development'
require 'config/init'

# Always load this
require 'db/seeds/production'

if ENV['RACK_ENV'] == 'development' && !ENV['SKIP_DEV_SEEDS']
  require 'db/seeds/development'
end
