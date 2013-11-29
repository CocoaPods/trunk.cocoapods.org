require File.expand_path('../../../../app/models/github', __FILE__)
require 'yaml'

module Pod
  module TrunkApp
    class GitHub
      alias_method :_perform_request, :perform_request
      def perform_request(method, path, body = nil)
        @last_response = _perform_request(method, path, body)
      end
      attr_reader :last_response
    end
  end
end

FIXTURE_DIR = File.expand_path('..', __FILE__)

$stdout.sync = true

def perform_action(name, *args)
  print "Perform `#{name}: "
  result = @github.send(name, *args)
  File.open(File.join(FIXTURE_DIR, "#{name}.yaml"), 'w') { |f| f << @github.last_response.to_yaml }
  puts result
  result
end

@github = Pod::TrunkApp::GitHub.new(ENV['GH_REPO'], 'master', :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic')

latest_commit_sha = perform_action(:fetch_latest_commit_sha)

base_tree_sha = perform_action(:fetch_base_tree_sha, latest_commit_sha)

destination_path = 'AFNetworking/1.2.0/AFNetworking.podspec.yaml'
data = File.read(File.expand_path('../../AFNetworking.podspec', __FILE__))
new_tree_sha = perform_action(:create_new_tree, base_tree_sha, destination_path, data)

name = `git config --global user.name`.strip
email = `git config --global user.email`.strip
new_commit_sha = perform_action(:create_new_commit, new_tree_sha, latest_commit_sha, '[Add] AFNetworking 1.2.0', name, email)

perform_action(:add_commit_to_branch, new_commit_sha, 'master')
