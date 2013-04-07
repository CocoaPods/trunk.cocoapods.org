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

desc 'Run the specs'
task :spec do
  sh "bacon #{FileList['spec/**/*_spec.rb'].shuffle.join(' ')}"
end

task :default => :spec
