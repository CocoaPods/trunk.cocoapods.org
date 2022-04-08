module SpecHelpers
  module CommitResponse
    def response(status = nil, body = nil, &block)
      block ||= lambda { REST::Response.new(status, {}, body) }
      Pod::TrunkApp::GitHub::CommitResponse.new(&block)
    end
  end
end
