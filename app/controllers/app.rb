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

        unless valid_specification?
          error 422, validation_errors.to_yaml
        end

        version_name = specification.version.to_s
        # Always set the location of the resource, even when the pod version already exists.
        headers 'Location' => url("/pods/#{specification.name}/versions/#{version_name}")

        pod = Pod.find_or_create(:name => specification.name)
        # TODO use a unique index in the DB for this instead?
        if pod.versions_dataset.where(:name => version_name).first
          error 409, "Unable to accept duplicate entry for: #{specification}".to_yaml
        end
        version = pod.add_version(:name => version_name)
        halt 202
      end

      get '/pods/:name/versions/:version' do
        if pod = Pod.find(:name => params[:name])
          if version = pod.versions_dataset.where(:name => params[:version]).first
            messages = version.submission_job.log_messages.map do |log_message|
              { log_message.created_at => log_message.message }
            end
            halt(version.published? ? 200 : 102, messages.to_yaml)
          end
        end
        error 404
      end

      private

      def specification
        @specification ||= begin
          hash = YAML.safe_load(request.body)
          Specification.from_hash(hash) if hash.is_a?(Hash)
        end
      end

      def linter
        @linter ||= Specification::Linter.new(specification)
      end

      def valid_specification?
        linter.lint
      end

      def validation_errors
        results = {}
        results['warnings'] = linter.warnings.map(&:message) unless linter.warnings.empty?
        results['errors']   = linter.errors.map(&:message)   unless linter.errors.empty?
        results
      end
    end
  end
end
