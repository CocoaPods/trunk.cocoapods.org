ENV['TRUNK_APP_PUSH_ALLOWED'] = 'true'

require 'app/controllers/app_controller'
require 'app/controllers/api/pods_controller'
require 'app/controllers/api/sessions_controller'

require 'rack/test'

require 'rest'
module REST
  def self.mock_response(status, headers, body)
    @mock_response = Response.new(status, headers, body)
  end

  def self.put(url, body, headers, auth)
    @mock_response
  ensure
    @mock_response = nil
  end
end

module Pod
  module TrunkApp
    class SeedAPI
      include Rack::Test::Methods

      def initialize
        header 'Content-Type', 'application/json; charset=utf-8'
      end

      def perform(method, route, expected_status, data = nil)
        send(method, route, data.nil? ? nil : data.to_json)
        unless last_response.status == expected_status
          raise "[#{app.name.split('::').last}][#{method.to_s.upcase} " \
                "#{route}][#{last_response.status}] Failed to perform with: " \
                "#{data.inspect}.\nResponse: #{last_response.inspect}"
        end
        unless last_response.body.blank?
          begin
            JSON.parse(last_response.body)
          rescue JSON::ParserError
            nil
          end
        end
      end
    end

    class SeedAPI
      class Sessions < SeedAPI
        def app
          SessionsController
        end

        def create(params)
          puts "Signing in as: #{params[:name]} <#{params[:email]}>"
          json = perform(:post, '/', 201, params)
          session = Session.find(:token => json['token'])
          verify(session.verification_token)
          session.token
        end

        def verify(token)
          perform(:get, "/verify/#{token}", 200)
        end
      end

      class Pods < SeedAPI
        def app
          PodsController
        end

        def initialize(token)
          header 'Authorization', "Token #{token}"
          super()
        end

        def add_owner(pod_name, email)
          perform(:patch, "/#{pod_name}/owners", 200, :email => email)
        end

        def create_from_name(pod_name)
          @push_count = 0
          source = ::Pod::Source.new(File.expand_path('~/.cocoapods/repos/master'))
          set = source.set(pod_name)
          set.versions.each do |version|
            spec = set.specification
            create_from_spec(spec)
            unless set.acceptable_versions.size == 1
              set.required_by(::Pod::Dependency.new(pod_name, "< #{version}"), 'Seeds')
            end
          end
          @push_count = nil
        end

        def create_from_spec(spec)
          puts "Pushing pod: #{spec.name} <#{spec.version}>"
          commit_sha = nil
          Dir.chdir(spec.defined_in_file.dirname) do
            commit_sha = `git log -n 1 --pretty="%H" -- '#{spec.defined_in_file.basename}'`.strip
          end
          if commit_sha.blank?
            raise 'Unable to determine commit sha!'
          end
          # Every 4th push fails
          if @push_count && (@push_count % 4) == 3
            REST.mock_response([422, 500][rand(2)], {}, { :error => 'Oh noes!' }.to_json)
            perform(:post, '/', 500, spec)
          else
            REST.mock_response(201, {}, { :commit => { :sha => commit_sha } }.to_json)
            perform(:post, '/', 302, spec)
          end
          @push_count += 1 if @push_count
        end
      end
    end
  end
end

# -------------------------------------------------------------------------------------------------

sessions = Pod::TrunkApp::SeedAPI::Sessions.new

# Create unclaimed pods and owner
token = sessions.create(:email => Pod::TrunkApp::Owner::UNCLAIMED_OWNER_EMAIL)
pods = Pod::TrunkApp::SeedAPI::Pods.new(token)
# Add an unclaimed pod by Orta
pods.create_from_name('ORStackView')

# Import work by Orta
token = sessions.create(:email => 'orta@example.com', :name => 'Orta')
pods = Pod::TrunkApp::SeedAPI::Pods.new(token)
pods.create_from_name('ARAnalytics')
# Adding second owner
sessions.create(:email => 'artsy@example.com', :name => 'Artsy')
pods.add_owner('ARAnalytics', 'artsy@example.com')

# Import work by Mattt Thompson
token = sessions.create(:email => 'mattt@example.com', :name => 'Mattt Thompson')
pods = Pod::TrunkApp::SeedAPI::Pods.new(token)
pods.create_from_name('AFNetworking')
pods.create_from_name('AFIncrementalStore')

# Import work by Kyle Fuller
token = sessions.create(:email => 'kyle@example.com', :name => 'Kyle Fuller')
pods = Pod::TrunkApp::SeedAPI::Pods.new(token)
pods.create_from_name('KFData')

# Create a few disputes
puts 'Creating disputes'
claimer = Pod::TrunkApp::Owner.find_by_email('orta@example.com')
dispute = Pod::TrunkApp::Dispute.create(:claimer => claimer, :message => 'The Pod ORStackView is mine!')
dispute = Pod::TrunkApp::Dispute.create(:claimer => claimer, :message => "Oops, KFData isn't mine.", :settled => true)

# Create session for current user
email = "#{ENV['USER']}@example.com"
name = `git config --global user.name`.strip
token = sessions.create(:email => email, :name => name, :description => 'Created from dev seeds')
puts
puts "[!] You now have a verified session for `#{name} <#{email}>': #{token}"
