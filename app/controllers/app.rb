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
        spec = YAML.load(params['yaml'])
        version = PodVersion.by_name_and_version(spec['name'], spec['version'])

        status 200
      end
    end
  end
end
