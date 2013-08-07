desc 'Install the dependencies'
task :bootstrap do
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

  namespace :db do
    desc 'Show schema'
    task :schema do
      $:.unshift(File.expand_path('../', __FILE__))
      require 'db/config'
      require 'terminal-table'
      DB.tables.each do |table|
        p table
        schema = DB.schema(table)
        puts Terminal::Table.new(
          :headings => [:name, *schema[0][1].keys],
          :rows => schema.map { |c| [c[0], *c[1].values.map(&:inspect)] }
        )
        puts
      end
    end

    desc 'Run migrations'
    task :migrate do
      $:.unshift(File.expand_path('../', __FILE__))
      require 'db/config'
      Sequel::Migrator.run(DB, File.join(ROOT, 'db/migrations'))
    end
  end

  desc 'Starts processes for local development'
  task :serve do
    exec "env PORT=4567 RACK_ENV=development foreman start"
  end

  desc 'Run the specs'
  task :spec do
    sh "bacon #{FileList['spec/**/*_spec.rb'].shuffle.join(' ')}"
  end

  desc 'Use Kicker to automatically run specs'
  task :kick do
    exec 'kicker -c -rruby -b bacon'
  end

  task :default => :spec
rescue LoadError => e
  puts "[!] The normal tasks have been disabled: #{e.message}"
end
