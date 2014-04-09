require 'rubygems'
require 'bundler/setup'

require 'rest'
require 'json'
require 'yaml'

OWNER = 'alloy'
REPO  = 'push.cocoapods.org-test'
auth_params = { :username => ENV['GH_USERNAME'], :password => ENV['GH_PASSWORD'] }

def url(path)
  "https://api.github.com/repos/#{OWNER}/#{REPO}/#{path}"
end

def handle_response(response)
  body = JSON.parse(response.body)
  puts "[#{response.status_code}] #{body.inspect}"
  puts
  puts response.to_yaml
  puts
  exit 1 unless response.success?
  body
end

#### Collect metadata

response = handle_response(REST.get(url('git/refs/heads/master'), {}, auth_params))
sha_latest_commit = response['object']['sha']

response = handle_response(REST.get(url("git/commits/#{sha_latest_commit}"), {}, auth_params))
sha_base_tree = response['tree']['sha']

#### Create Git objects

# test_name = "test-#{Time.now.to_i}"
test_name = "AFNetworking-1.2.0-#{Time.now.to_i}"

# Create new tree entry (the contents)
body = { 'base_tree' => sha_base_tree, 'tree' => [{ 'path' => "#{test_name}/1.2.0/#{test_name}.podspec", 'encoding' => 'utf-8', 'content' => File.read('spec/fixtures/AFNetworking.podspec'), 'mode' => '100644' }] }.to_json
p body
response = handle_response(REST.post(url('git/trees'), body, {}, auth_params))
sha_new_tree = response['sha']

# Create new commit
body = { 'parents' => [sha_latest_commit], 'tree' => sha_new_tree, 'message' => "Pull-request for #{test_name}." }.to_json
p body
response = handle_response(REST.post(url('git/commits'), body, {}, auth_params))
sha_new_commit = response['sha']

# Create new branch
body = { 'ref' => "refs/heads/#{test_name}", 'sha' => sha_new_commit }.to_json
p body
response = handle_response(REST.post(url('git/refs'), body, {}, auth_params))
sha_new_branch = response['object']['sha']

#### Create pull-request

body = { 'title' => "[PUSH] Add #{test_name}", 'body' => ':heart:', 'head' => "refs/heads/#{test_name}", 'base' => 'master' }.to_json
p body
response = handle_response(REST.post(url('pulls'), body, {}, auth_params))
p response
pr_number = response['number']

#### Merge pull-request

body = { 'commit_message' => 'Merged by remote app.' }.to_json
p body
response = handle_response(REST.put(url("pulls/#{pr_number}/merge"), body, {}, auth_params))
p response
