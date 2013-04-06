require 'rubygems'
require 'bundler/setup'

namespace :stories do
  desc 'Convert the requirements txt file to html'
  task :convert do
    sh 'saga convert --template design/requirements_template design/requirements.txt > design/requirements.html'
  end
end
