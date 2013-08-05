module Pod
  module PushApp
    class SpecificationWrapper
      def self.from_yaml(yaml)
        hash = YAML.safe_load(yaml)
        if hash.is_a?(Hash)
          new(Specification.from_hash(hash))
        end
      end

      def initialize(specification)
        @specification = specification
      end

      def name
        @specification.name
      end

      def version
        @specification.version.to_s
      end

      def to_s
        @specification.to_s
      end

      def to_yaml
        @specification.to_yaml
      end

      def valid?
        linter.lint
      end

      def validation_errors
        results = {}
        results['warnings'] = linter.warnings.map(&:message) unless linter.warnings.empty?
        results['errors']   = linter.errors.map(&:message)   unless linter.errors.empty?
        results
      end

      private

      def linter
        @linter ||= Specification::Linter.new(@specification)
      end
    end
  end
end
