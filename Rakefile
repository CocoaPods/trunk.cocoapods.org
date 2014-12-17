desc 'Install the dependencies'
task :bootstrap do
  sh 'git submodule update --init'
  sh 'bundle install'
end

begin
  require 'rubygems'
  require 'bundler/setup'

  namespace :stories do
    desc 'Add IDs to new stories'
    task :autofill do
      tmp = '/tmp/push.cocoapods.org-requirements.txt'
      sh "saga autofill design/requirements.txt > #{tmp}"
      mv tmp, 'design/requirements.txt'
    end

    desc 'Convert the requirements txt file to html'
    task :convert do
      sh 'saga convert --template design/requirements_template design/requirements.txt > design/requirements.html'
    end
  end

  task :env do
    $LOAD_PATH.unshift(File.expand_path('../', __FILE__))
    require 'config/init'
  end

  task :rack_env do
    ENV['RACK_ENV'] ||= 'development'
  end

  namespace :db do
    def schema
      require 'terminal-table'
      result = ''
      DB.tables.each do |table|
        result << "#{table}\n"
        schema = DB.schema(table)
        terminal_table = Terminal::Table.new(
          headings: [:name, *schema[0][1].keys],
          rows: schema.map { |c| [c[0], *c[1].values.map(&:inspect)] }
        )
        result << "#{terminal_table}\n\n"
      end
      result
    end

    desc 'Show schema'
    task :schema => :env do
      puts schema
    end

    desc 'Run migrations'
    task :migrate => :rack_env do
      ENV['TRUNK_APP_LOG_TO_STDOUT'] = 'true'
      Rake::Task[:env].invoke
      version = ENV['VERSION'].to_i if ENV['VERSION']
      Sequel::Migrator.run(DB, File.join(ROOT, 'db/migrations'), :target => version)
      File.open('db/schema.txt', 'w') { |file| file.write(schema) }
    end

    desc 'Drop DB for RACK_ENV'
    task :drop => :rack_env do
      sh "dropdb trunk_cocoapods_org_#{ENV['RACK_ENV']}"
    end

    desc 'Create DB for RACK_ENV'
    task :create => :rack_env do
      sh "createdb -h localhost trunk_cocoapods_org_#{ENV['RACK_ENV']} -E UTF8"
    end

    desc 'Seed DB'
    task :seed => :rack_env do
      sh 'bundle exec ruby db/seeds.rb'
    end

    desc 'Create, migrate, and seed the DB for RACK_ENV'
    task :bootstrap => [:create, :migrate, :seed]

    desc 'Drop and then bootstrap the DB for RACK_ENV'
    task :reset => [:drop, :bootstrap]
  end

  desc 'Starts a interactive console with the model env loaded'
  task :console do
    exec 'irb', '-I', File.expand_path('../', __FILE__), '-r', 'config/init'
  end

  desc 'Starts processes for local development'
  task :serve do
    exec 'env PORT=4567 RACK_ENV=development foreman start'
  end

  desc 'Run the specs'
  task :spec do
    title 'Running the specs'
    sh "bacon #{FileList['spec/**/*_spec.rb'].shuffle.join(' ')}"

    title 'Checking code style'
    Rake::Task[:rubocop].invoke
  end

  desc 'Use Kicker to automatically run specs'
  task :kick do
    exec 'bundle exec kicker -c'
  end

  task :default => :spec

#-- Rubocop -------------------------------------------------------------------

  begin
    require 'rubocop/rake_task'
    Rubocop::RakeTask.new(:rubocop) do |task|
      task.patterns = FileList['{app,config,db,lib,spec}/**/*.rb']
      task.fail_on_error = true
    end
  rescue LoadError
    puts "[!] The Rubocop tasks have been disabled"
  end

rescue SystemExit, LoadError => e
  puts "[!] The normal tasks have been disabled: #{e.message}"
end

#-- UI ------------------------------------------------------------------------

def title(title)
  cyan_title = "\033[0;36m#{title}\033[0m"
  puts
  puts '-' * 80
  puts cyan_title
  puts '-' * 80
  puts
end
