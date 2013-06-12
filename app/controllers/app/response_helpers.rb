module Pod
  module PushApp
    class App
      module ResponseHelpers
        def yaml_error(status, message)
          error(status, { 'error' => message }.to_yaml)
        end

        def yaml_message(status, content)
          halt(status, content.to_yaml)
        end
      end

      helpers ResponseHelpers
    end
  end
end