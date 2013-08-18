module Pod
  module TrunkApp
    class APIController
      before do
        content_type 'text/yaml'
        if request.post? && request.media_type != 'text/yaml'
          yaml_error(415, "Unable to accept input with Content-Type `#{request.media_type}`, must be `text/yaml`.")
        end
      end

      private

      def yaml_error(status, message)
        error(status, { 'error' => message }.to_yaml)
      end

      def yaml_message(status, content)
        halt(status, content.to_yaml)
      end
    end
  end
end
