require 'safe_yaml'
require 'sinatra/base'

require 'cocoapods-core/specification'
require 'cocoapods-core/specification/linter'

require 'db/config'
require 'app/models/github'
require 'app/models/pod'

SafeYAML::OPTIONS[:default_mode] = :safe

module Pod
  module PushApp
    class App < Sinatra::Base
      before do
        content_type 'text/yaml'
        unless request.media_type == 'text/yaml'
          error 415, "Unable to accept input with Content-Type `#{request.media_type}`, must be `text/yaml`.".to_yaml
        end
      end

      post '/pods' do
        if specification.nil?
          error 400, 'Unable to load a Pod Specification from the provided input.'.to_yaml
        end

        linter = Specification::Linter.new(specification)
        unless linter.lint
          results = {}
          results['warnings'] = linter.warnings.map(&:message) unless linter.warnings.empty?
          results['errors']   = linter.errors.map(&:message)   unless linter.errors.empty?
          error 422, results.to_yaml
        end

        pod_version = PodVersion.by_name_and_version(specification.name, specification.version.to_s)
        halt 202
      end

      private

      def specification
        @specification ||= begin
          hash = YAML.safe_load(request.body)
          Specification.from_hash(hash) if hash.is_a?(Hash)
        end
      end
    end
  end
end
