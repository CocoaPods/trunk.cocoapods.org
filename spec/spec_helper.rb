require 'bacon'
require 'mocha-on-bacon'

ENV['GH_REPO']     = 'CocoaPods/Specs'
ENV['GH_USERNAME'] = 'alloy'
ENV['GH_PASSWORD'] = 'secret'

ROOT = File.expand_path('../../', __FILE__)
$:.unshift ROOT

class Bacon::Context
  def fixture(filename)
    File.join(ROOT, 'spec/fixtures', filename)
  end

  def fixture_read(filename)
    File.read(fixture(filename))
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
