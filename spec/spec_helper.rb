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

# SHAs used in PR fixtures
BASE_COMMIT_SHA = '632671a3f28771a3631119354731dba03963a276'
BASE_TREE_SHA = 'f93e3a1a1525fb5b91020da86e44810c87a2d7bc'
NEW_TREE_SHA = '18f8a32cdf45f0f627749e2be25229f5026f93ac'
NEW_COMMIT_SHA = '4ebf6619c831963fafb7ccd8e9aa3079f00ac41d'
NEW_BRANCH_REF = 'refs/heads/AFNetworking-1.2.0'
DESTINATION_PATH = 'AFNetworking/1.2.0/AFNetworking.podspec'
MESSAGE = '[Add] AFNetworking 1.2.0'
NEW_BRANCH_NAME = 'AFNetworking-1.2.0'
NEW_PR_NUMBER = 3
