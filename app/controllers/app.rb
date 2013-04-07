require 'db/config'
require 'app/models/github'
require 'app/models/pod'

require 'sinatra/base'
require 'sinatra/param'
require 'rack/contrib'

module Pod
  module PushApp
    class App < Sinatra::Base
      use Rack::PostBodyContentTypeParser
      helpers Sinatra::Param

      before do
        content_type :json
      end

      post '/pods' do
        param 'specification', String
        param 'yaml', String

        # TODO
        # * use dumb-yaml for security
        # * wrap in a transaction for error handling
        # * store github pull-request progress state
        spec = YAML.load(params['yaml'])
        name, version = spec['name'], spec['version']

        pod_version = PodVersion.by_name_and_version(name, version)

        title  = "[Add] #{name} (#{version})"
        branch = "merge-#{pod_version.id}"
        body   = branch
        path   = File.join(name, version, "#{name}.podspec")
        pull_request_number = GitHub.create_pull_request(title, body, branch, path, params['specification'])

        pod_version.submitted_as_pull_request!

        headers 'Location' => "https://github.com/#{GitHub::REPO}/pull/#{pull_request_number}"
        status 200
      end
    end
  end
end
