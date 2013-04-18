require 'safe_yaml'
require 'sinatra/base'

require 'cocoapods-core/specification'

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
        hash = YAML.safe_load(request.body)
        if hash.is_a?(Hash)
          spec = Specification.from_hash(hash)
          if spec.name
            pod_version = PodVersion.by_name_and_version(spec.name, spec.version.to_s)
            halt 202
          end
        end
        error 400
      end
    end
  end
end
