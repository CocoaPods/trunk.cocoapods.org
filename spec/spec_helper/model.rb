module SpecHelpers
  module ModelAssertions
    def validate_with(attr, value, error_on = nil)
      model = @object.class.name.split('::').last
      satisfy "expected `#{model}' to #{'not ' if @negated}be valid with `#{attr}' set to: #{value.inspect}" do
        @object.send("#{attr}=", value)
        @object.valid?
        @object.errors[error_on || attr] == nil
      end
    end
  end
end
