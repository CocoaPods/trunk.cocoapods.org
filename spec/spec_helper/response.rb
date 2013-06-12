module SpecHelpers
  module Response
    def yaml_response
      YAML.load(last_response.body)
    end
  end
end