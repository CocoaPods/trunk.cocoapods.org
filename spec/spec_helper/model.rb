module SpecHelpers
  module ModelAssertions
    def validate_with(attr, value)
      model = @object.class.name.split('::').last
      satisfy "expected `#{model}' to #{'not ' if @negated}be valid with `#{attr}' set to: #{value.inspect}" do
        @object.send("#{attr}=", value)
        @object.valid?
        @object.errors.on(attr).nil?
      end
    end
  end
end
