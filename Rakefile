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
    $:.unshift(File.expand_path('../', __FILE__))
    require 'config/init'
  end

  namespace :db do
    desc 'Show schema'
    task :schema => :env do
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
      ENV['TRUNK_APP_LOG_TO_STDOUT'] = 'true'
      Rake::Task[:env].invoke
      version = ENV['VERSION'].to_i if ENV['VERSION']
      Sequel::Migrator.run(DB, File.join(ROOT, 'db/migrations'), :target => version)
    end
    
    desc 'Drop all DBs'
    task :drop do
      `dropdb trunk_cocoapods_org_test`
      `dropdb trunk_cocoapods_org_development`
      `dropdb trunk_cocoapods_org_production`
    end
    
    desc 'Create all DBs'
    task :create do
      `createdb -h localhost trunk_cocoapods_org_test -E UTF8`
      `createdb -h localhost trunk_cocoapods_org_development -E UTF8`
      `createdb -h localhost trunk_cocoapods_org_production -E UTF8`
    end
    
    desc 'Create all DBs'
    task :bootstrap do
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      %w{test development production}.each do |env|
        sh "env RACK_ENV=#{env} rake db:migrate"
      end
    end
    
    namespace :seed do
      desc 'Seed the database with simple data (will destroy existing data)'
      task :simple => :env do
        require 'app/controllers/app_controller'
        Pod::TrunkApp::Pod.create(:name => 'ADTestPod').add_version(:name => '1.0.0')
          .add_commit(
            :owner => Pod::TrunkApp::Owner.create(:name => 'Test User', :email => 'test.user@example.com'),
            :sha => '3ca23060197547eef92983f15590b5a87270615f',
            :specification_data => '{"SPEC":"DATA"}'
          )
      end
    end
  end

  desc 'Starts a interactive console with the model env loaded'
  task :console do
    exec 'irb', '-I', File.expand_path('../', __FILE__), '-r', 'config/init'
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
rescue SystemExit, LoadError => e
  puts "[!] The normal tasks have been disabled: #{e.message}"
end
