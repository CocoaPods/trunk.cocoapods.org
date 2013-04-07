require 'rubygems'
require 'bundler/setup'

require 'rest'
require 'json'

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
  exit 1 unless response.success?
  body
end

#### Collect metadata

response = handle_response(REST.get(url("git/refs/heads/master"), {}, auth_params))
sha_latest_commit = response['object']['sha']

response = handle_response(REST.get(url("git/commits/#{sha_latest_commit}"), {}, auth_params))
sha_base_tree = response['tree']['sha']

#### Create Git objects

test_name = "test-#{Time.now.to_i}"

# Create new tree entry (the contents)
body = { "base_tree" => sha_base_tree, "tree" => [{ "path" => "#{test_name}/1.0.0/#{test_name}.podspec", "encoding" => "utf-8", "content" => DATA.read, "mode" => "100644" }] }.to_json
p body
response = handle_response(REST.post(url("git/trees"), body, {}, auth_params))
sha_new_tree = response['sha']

# Create new commit
body = { "parents" => [sha_latest_commit], "tree" => sha_new_tree, "message" => "Pull-request for #{test_name}." }.to_json
p body
response = handle_response(REST.post(url("git/commits"), body, {}, auth_params))
sha_new_commit = response['sha']

# Create new branch
body = { "ref" => "refs/heads/#{test_name}", "sha" => sha_new_commit }.to_json
p body
response = handle_response(REST.post(url("git/refs"), body, {}, auth_params))
sha_new_branch = response['object']['sha']

#### Create pull-request

body = { "title" => "[PUSH] Add #{test_name}", "body" => ":heart:", "head" => sha_new_branch, "base" => "master" }.to_json
p body
response = handle_response(REST.post(url("pulls"), body, {}, auth_params))
p response



__END__
Pod::Spec.new do |s|
  s.name     = 'AFNetworking'
  s.version  = '1.2.0'
  s.license  = 'MIT'
  s.summary  = 'A delightful iOS and OS X networking framework.'
  s.homepage = 'https://github.com/AFNetworking/AFNetworking'
  s.authors  = { 'Mattt Thompson' => 'm@mattt.me', 'Scott Raymond' => 'sco@gowalla.com' }
  s.source   = { :git => 'https://github.com/AFNetworking/AFNetworking.git', :tag => '1.2.0' }
  s.source_files = 'AFNetworking'
  s.requires_arc = true

  s.ios.deployment_target = '5.0'
  s.ios.frameworks = 'MobileCoreServices', 'SystemConfiguration', 'Security'

  s.osx.deployment_target = '10.7'
  s.osx.frameworks = 'CoreServices', 'SystemConfiguration', 'Security'

  s.prefix_header_contents = <<-EOS
#import <Availability.h>

#define _AFNETWORKING_PIN_SSL_CERTIFICATES_

#if __IPHONE_OS_VERSION_MIN_REQUIRED
  #import <SystemConfiguration/SystemConfiguration.h>
  #import <MobileCoreServices/MobileCoreServices.h>
#else
  #import <SystemConfiguration/SystemConfiguration.h>
  #import <CoreServices/CoreServices.h>
#endif
EOS
end
