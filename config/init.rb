# -- General ------------------------------------------------------------------

ROOT = File.expand_path('../../', __FILE__)

ENV['RACK_ENV'] ||= 'production'
ENV['DATABASE_URL'] ||= "postgres://localhost/trunk_cocoapods_org_#{ENV['RACK_ENV']}"

require 'active_support/core_ext'

require 'safe_yaml'
SafeYAML::OPTIONS[:default_mode] = :safe

if !defined?(IRB) && ENV['RACK_ENV'] == 'production'
  require 'newrelic_rpm'
end

# -- Logging ------------------------------------------------------------------

require 'logger'
require 'fileutils'

if ENV['TRUNK_APP_LOG_TO_STDOUT']
  STDOUT.sync = true
  STDERR.sync = true
  TRUNK_APP_LOGGER = Logger.new(STDOUT)
  TRUNK_APP_LOGGER.level = Logger::INFO
else
  FileUtils.mkdir_p(File.join(ROOT, 'log'))
  TRUNK_APP_LOG_FILE = File.new(File.join(ROOT, "log/#{ENV['RACK_ENV']}.log"), 'a+')
  TRUNK_APP_LOG_FILE.sync = true
  TRUNK_APP_LOGGER = Logger.new(TRUNK_APP_LOG_FILE)
  TRUNK_APP_LOGGER.level = Logger::DEBUG
end

# -- Database -----------------------------------------------------------------

require 'sequel'
require 'pg'

db_loggers = []
db_loggers << TRUNK_APP_LOGGER # TODO For now also enable DB logger in production. unless ENV['RACK_ENV'] == 'production'
DB = Sequel.connect(ENV['DATABASE_URL'], :loggers => db_loggers)
Sequel.extension :core_extensions, :migration

# -- Console ------------------------------------------------------------------

if defined?(IRB)
  puts "[!] Loading `#{ENV['RACK_ENV']}' environment."
  Dir.chdir(ROOT) do
    Dir.glob('app/models/*.rb').each do |model|
      require model[0..-4]
    end
  end
  include Pod::TrunkApp
end
