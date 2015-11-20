require 'bacon'
require 'pretty_bacon'

require 'rack/test'
require 'digest'

require 'mocha-on-bacon'
Mocha::Configuration.prevent(:stubbing_non_existent_method)

require 'cocoapods-core'

ENV['RACK_ENV'] = 'test'

ENV['GH_REPO']     = 'CocoaPods/Specs'
ENV['GH_USERNAME'] = 'alloy'
ENV['GH_EMAIL']    = 'bot@example.com'
ENV['GH_TOKEN']    = 'secret'

ENV['TRUNK_APP_PUSH_ALLOWED']   = 'true'
ENV['TRUNK_APP_ADMIN_PASSWORD'] = Digest::SHA2.hexdigest('secret')

$LOAD_PATH.unshift File.expand_path('../../', __FILE__)
require 'config/init'
require 'app/controllers/app_controller'

def DB.test_safe_transaction(&block)
  DB.transaction(:savepoint => true, &block)
end

$LOAD_PATH.unshift(ROOT, 'spec')
Dir.glob(File.join(ROOT, 'spec/spec_helper/**/*.rb')).each do |filename|
  require File.join('spec_helper', File.basename(filename, '.rb'))
end

class Should
  include SpecHelpers::ModelAssertions
end

module Bacon
  module BacktraceFilter
    # Gray-out those backtrace lines that are usually less interesting.
    def handle_summary
      ErrorLog.gsub!(/\t(.+?)\n/) do |line|
        if Regexp.last_match[1].start_with?('/')
          downcased = Regexp.last_match[1].downcase
          if downcased.include?('cocoapods') && !downcased.include?('spec/spec_helper')
            line
          else
            "\e[0;37m#{line}\e[0m"
          end
        else
          line
        end
      end
      super
    end
  end

  extend BacktraceFilter
end

require 'nokogiri'

class Bacon::Context
  def test_controller!(app)
    extend Rack::Test::Methods
    extend SpecHelpers::Access

    singleton_class.send(:define_method, :app) { app }
    singleton_class.send(:define_method, :response_doc) { Nokogiri::HTML(last_response.body) }
  end

  def fixture(filename)
    File.join(ROOT, 'spec/fixtures', filename)
  end

  def fixture_read(filename)
    File.read(fixture(filename))
  end

  def fixture_specification(filename)
    Pod::Specification.from_file(fixture(filename))
  end

  def fixture_json(filename)
    JSON.parse(fixture_read(filename))
  end

  def fixture_response(name)
    YAML.load(fixture_read("GitHub/#{name}.yaml"))
  end

  def rest_response(body_or_fixture_name, code = 200, header = nil)
    if File.exist?(fixture(body_or_fixture_name))
      body = fixture_read(body_or_fixture_name)
    else
      body = body_or_fixture_name
    end
    REST::Response.new(code, header, body)
  end

  def fixture_new_commit_sha
    @@fixture_new_commit_sha ||= JSON.parse(fixture_response('create_new_commit').body)['commit']['sha']
  end

  alias_method :run_requirement_before_sequel, :run_requirement
  def run_requirement(description, spec)
    TRUNK_APP_LOGGER.info('-' * description.size)
    TRUNK_APP_LOGGER.info(description)
    TRUNK_APP_LOGGER.info('-' * description.size)
    Sequel::Model.db.transaction(:rollback => :always) do
      run_requirement_before_sequel(description, spec)
    end
  end
end

module Kernel
  alias_method :describe_before_controller_tests, :describe

  def describe(*description, &block)
    if description.first.is_a?(Class) && description.first.superclass.ancestors.include?(Pod::TrunkApp::AppController)
      klass = description.first
      # Configure controller test and always use HTTPS
      describe_before_controller_tests(*description) do
        test_controller!(klass)
        before { header 'X-Forwarded-Proto', 'https' }
        instance_eval(&block)
      end
    else
      describe_before_controller_tests(*description, &block)
    end
  end
end

require 'net/http'
module Net
  class HTTP
    class << self
      attr_accessor :last_started_request
    end

    def start
      self.class.last_started_request = self
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      def response.body
        'OK'
      end
      response
    end

    class TryingToMakeHTTPConnectionException < StandardError; end
    def connect
      raise TryingToMakeHTTPConnectionException, "Please mock your HTTP calls so you don't do any HTTP requests."
    end
  end
end

require 'rfc822'
module RFC822
  def self.mx_records(address)
    if address == Pod::TrunkApp::Owner::UNCLAIMED_OWNER_EMAIL || address.split('@').last == 'example.com'
      [MXRecord.new(20, 'mail.example.com')]
    else
      []
    end
  end
end

# Create Owners.unclaimed owner.
#
def seed_unclaimed
  before do
    Pod::TrunkApp::Owner.create(:email => Pod::TrunkApp::Owner::UNCLAIMED_OWNER_EMAIL, :name => 'Unclaimed')
  end
  after do
    Pod::TrunkApp::Owner.unclaimed.delete
  end
end

# Used in GitHub fixtures
DESTINATION_PATH = 'AFNetworking/1.2.0/AFNetworking.podspec.yaml'
MESSAGE = '[Add] AFNetworking 1.2.0'
