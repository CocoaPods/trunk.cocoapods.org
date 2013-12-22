module Pod
  module TrunkApp
    class APIController
      before do
        type = content_type(:json)
        if (request.post? || request.put?) && request.media_type != 'application/json'
          json_error(415, "Unable to accept input with Content-Type `#{request.media_type}`, must be `application/json`.")
        end
      end

      private

      def json_error(status, message)
        error(status, { 'error' => message }.to_json)
      end

      def json_message(status, content)
        halt(status, content.to_json)
      end
    end
  end
end
