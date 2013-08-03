ENV['RACK_ENV'] ||= 'production'
ENV['DATABASE_URL'] ||= "postgres://localhost/push_cocoapods_org_#{ENV['RACK_ENV']}"

ROOT = File.expand_path('../../', __FILE__)

require 'sequel'
require 'pg'

require 'logger'
require 'fileutils'

if ENV['RACK_ENV'] == 'production'
  PUSH_LOGGER = Logger.new(STDOUT)
  PUSH_LOGGER.level = Logger::INFO
else
  FileUtils.mkdir_p(File.join(ROOT, 'log'))
  PUSH_LOG_FILE = File.new(File.join(ROOT, "log/#{ENV['RACK_ENV']}.log"), 'a+')
  PUSH_LOG_FILE.sync = true
  PUSH_LOGGER = Logger.new(PUSH_LOG_FILE)
  PUSH_LOGGER.level = Logger::DEBUG
end

db_loggers = []
db_loggers << PUSH_LOGGER unless ENV['RACK_ENV'] == 'production'
DB = Sequel.connect(ENV['DATABASE_URL'], :loggers => db_loggers)
Sequel.extension :core_extensions, :migration
Sequel::Migrator.run(DB, File.expand_path('../migrations', __FILE__))
