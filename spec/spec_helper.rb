require 'bacon'
require 'mocha-on-bacon'
require 'rack/test'

require 'cocoapods-core'

ENV['GH_REPO']      = 'CocoaPods/Specs'
ENV['GH_USERNAME']  = 'alloy'
ENV['GH_PASSWORD']  = 'secret'

ENV['RACK_ENV']     = 'test'
ENV['DATABASE_URL'] = 'postgres://localhost/push_cocoapods_org_test'

ROOT = File.expand_path('../../', __FILE__)
$:.unshift ROOT
require 'app/controllers/app'

Mocha::Configuration.prevent(:stubbing_non_existent_method)

class Bacon::Context
  def fixture(filename)
    File.join(ROOT, 'spec/fixtures', filename)
  end

  def fixture_read(filename)
    File.read(fixture(filename))
  end

  def fixture_specification(filename)
    Pod::Specification.from_file(fixture(filename))
  end

  alias_method :run_requirement_before_sequel, :run_requirement
  def run_requirement(description, spec)
    Sequel::Model.db.transaction(:rollback => :always) do
      run_requirement_before_sequel(description, spec)
    end
  end
end

require 'net/http'
module Net
  class HTTP
    class TryingToMakeHTTPConnectionException < StandardError; end
    def connect
      raise TryingToMakeHTTPConnectionException, "Please mock your HTTP calls so you don't do any HTTP requests."
    end
  end
end
