require 'sequel'
require 'pg'

DB = Sequel.connect(ENV['DATABASE_URL'])
Sequel.extension :core_extensions, :migration
Sequel::Migrator.run(DB, File.expand_path('../migrations', __FILE__))
