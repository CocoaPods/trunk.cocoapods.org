module SpecHelpers
  module CommitResponse
    def response(status = nil, body = nil, &)
      block ||= lambda { REST::Response.new(status, {}, body) }
      Pod::TrunkApp::GitHub::CommitResponse.new(&)
    end
  end
end
