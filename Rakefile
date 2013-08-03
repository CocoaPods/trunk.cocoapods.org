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

  desc 'Start the server'
  task :serve do
    exec "env PORT=4567 DATABASE_URL=postgres://localhost/push_cocoapods_org_dev foreman start"
  end

  desc 'Pushes the fixture podspec through the API'
  task :push do
    require 'rest'
    require 'json'
    require 'cocoapods-core'
    path = 'spec/fixtures/AFNetworking.podspec'
    spec = Pod::Specification.from_file(path)
    body = { 'specification' => File.read(path), 'yaml' => spec.to_yaml }.to_json
    response = REST.post('http://localhost:4567/pods', body, { 'Content-Type' => 'application/json' })
    puts "[#{response.status_code}] #{response.headers.inspect}"
  end

  desc 'Run the specs'
  task :spec do
    sh "bacon #{FileList['spec/**/*_spec.rb'].shuffle.join(' ')}"
  end

  task :default => :spec
rescue LoadError => e
  puts "[!] The normal tasks have been disabled: #{e.message}"
end
