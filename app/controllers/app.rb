require 'safe_yaml'
require 'sinatra/base'

require 'db/config'
require 'app/models/github'
require 'app/models/pod'

SafeYAML::OPTIONS[:default_mode] = :safe

module Pod
  module PushApp
    class App < Sinatra::Base
      before do
        error 415 unless request.media_type == 'text/yaml'
        content_type 'text/yaml'
      end

      post '/pods' do
        # TODO
        # * wrap in a transaction for error handling
        # * store github pull-request progress state
        spec = YAML.load(request.body)

        # TODO we should probably verify some more data
        if spec.is_a?(Hash) && (name = spec['name']) && (version = spec['version'])
          pod_version = PodVersion.by_name_and_version(name, version)

          #title  = "[Add] #{name} (#{version})"
          #branch = "merge-#{pod_version.id}"
          #body   = branch
          #path   = File.join(name, version, "#{name}.podspec")
          #pull_request_number = GitHub.create_pull_request(title, body, branch, path, params['specification'])

          #pod_version.submitted_as_pull_request!

          #headers 'Location' => "https://github.com/#{GitHub::REPO}/pull/#{pull_request_number}"
          status 202
        else
          error 400
        end
      end
    end
  end
end
