require 'sequel'
require 'pg'

require 'logger'
require 'fileutils'

FileUtils.mkdir_p(File.join(ROOT, 'log'))
PUSH_LOGGER = Logger.new(File.join(ROOT, "log/#{ENV['RACK_ENV']}.log"))
PUSH_LOGGER.level = Logger::DEBUG

DB = Sequel.connect(ENV['DATABASE_URL'], :loggers => [PUSH_LOGGER])
Sequel.extension :core_extensions, :migration
Sequel::Migrator.run(DB, File.expand_path('../migrations', __FILE__))
