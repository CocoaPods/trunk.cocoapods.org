ENV['RACK_ENV'] ||= 'production'
ENV['DATABASE_URL'] ||= "postgres://localhost/trunk_cocoapods_org_#{ENV['RACK_ENV']}"

ROOT = File.expand_path('../../', __FILE__)

require 'sequel'
require 'pg'

require 'logger'
require 'fileutils'

if ENV['RACK_ENV'] == 'production'
  TRUNK_APP_LOGGER = Logger.new(STDOUT)
  TRUNK_APP_LOGGER.level = Logger::INFO
else
  FileUtils.mkdir_p(File.join(ROOT, 'log'))
  TRUNK_APP_LOG_FILE = File.new(File.join(ROOT, "log/#{ENV['RACK_ENV']}.log"), 'a+')
  TRUNK_APP_LOG_FILE.sync = true
  TRUNK_APP_LOGGER = Logger.new(TRUNK_APP_LOG_FILE)
  TRUNK_APP_LOGGER.level = Logger::DEBUG
end

require 'safe_yaml'
SafeYAML::OPTIONS[:default_mode] = :safe

db_loggers = []
db_loggers << TRUNK_APP_LOGGER unless ENV['RACK_ENV'] == 'production'
DB = Sequel.connect(ENV['DATABASE_URL'], :loggers => db_loggers)
Sequel.extension :core_extensions, :migration
Sequel::Migrator.run(DB, File.expand_path('../migrations', __FILE__))
