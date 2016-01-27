module SpecHelpers
  module Access
    class Macro
      def initialize(context, status_code, desc)
        @context = context
        @status_code = status_code
        @desc = desc
      end

      [:get, :post, :put, :patch, :delete].each do |method|
        class_eval <<-EOS, __FILE__, __LINE__ + 1
          def #{method}(route, &block)
            @context.it "\#{@desc} to access: #{method.to_s.upcase} \#{route}" do
              lambda {
                @context.send(:#{method}, route, @context.instance_eval(&block))
              }.should.not.change { total_db_record_count }
              @context.last_response.status.should == @status_code
            end
          end
        EOS
      end

      private

      def total_db_record_count
        DB.tables.map { |table| DB[table].count }.reduce(0) { |x, sum| sum + x }
      end
    end

    def should_require_login
      Macro.new(self, 401, 'requires login')
    end

    def should_disallow
      Macro.new(self, 403, 'is not allowed')
    end
  end
end
