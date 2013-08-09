module Pod
  module TrunkApp
    module ManageHelper
      def formatted_duration(seconds)
        components = []
        if seconds >= 60
          minutes, seconds = time_components(seconds, 60)
          if minutes >= 60
            hours, minutes = time_components(minutes, 60)
            if hours >= 24
              days, hours = time_components(hours, 24)
              components << formatted_time_component(days, 'day')
              components << formatted_time_component(hours, 'hour') if hours > 0
            else
              components << formatted_time_component(hours, 'hour')
              components << formatted_time_component(minutes, 'minute') if minutes > 0
            end
          else
            components << formatted_time_component(minutes, 'minute')
            components << formatted_time_component(seconds, 'second') if seconds > 0
          end
        else
          components << formatted_time_component(seconds, 'second')
        end
        components.join(' and ')
      end

      private

      def time_components(duration, base)
        [duration / base, duration % base]
      end

      def formatted_time_component(component, name)
        "#{component} #{name.pluralize(component)}"
      end
    end
  end
end
