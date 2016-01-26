module Pod
  module TrunkApp
    module ManageHelper
      # @return [String]
      #
      def formatted_duration(seconds)
        unit = find_biggest_time_unit(seconds)
        unit_count = seconds / unit_seconds(unit)
        result = formatted_time_component(unit_count, unit)

        remaining_seconds = seconds % unit_seconds(unit)
        unless remaining_seconds.zero?
          next_index = TIME_UNITS.index(unit) + 1
          next_unit = TIME_UNITS[next_index]
          next_unit_count = remaining_seconds / unit_seconds(next_unit)

          unless next_unit_count.zero?
            result << ' and '
            result << formatted_time_component(next_unit_count, next_unit)
          end
        end
        result
      end

      private

      # @return [Array] The time units sorted from biggest to smallest.
      #
      TIME_UNITS = [:day, :hour, :minute, :second]

      # @return [Hash] The duration in seconds of each time unit.
      #
      TIME_UNIT_SECONDS = {
        :day => 24 * 60 * 60,
        :hour => 60 * 60,
        :minute => 60,
        :second => 1,
      }

      def unit_seconds(unit)
        TIME_UNIT_SECONDS[unit]
      end

      # Returns the biggest time unit in the given time expressed in seconds.
      #
      # @param  [Fixnum] seconds The time expressed in seconds.
      #
      # @return [Symbol] The biggest unit.
      #
      def find_biggest_time_unit(seconds)
        current = :second
        TIME_UNITS.each do |unit|
          unit_seconds = unit_seconds(unit)
          if unit_seconds <= seconds
            if unit_seconds > unit_seconds(current)
              current = unit
            end
          end
        end
        current
      end

      # @return [String]
      #
      def formatted_time_component(component, name)
        unless component.zero?
          "#{component} #{name.to_s.pluralize(component)}"
        end
      end
    end
  end
end
