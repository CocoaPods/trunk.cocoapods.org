require 'open3'
require 'timeout'
require 'uri'

module ValidMXRecords
  def valid_mx_records?(address)
    address = address.to_s
    return false unless URI::MailTo::EMAIL_REGEXP.match?(address)

    host = address.split('@').last
    re = /[\w ]+?(\d+) (#{URI::REGEXP::PATTERN::HOSTNAME})\.\z/o

    Timeout.timeout(3) do
      output, status = Open3.capture2('/usr/bin/env', 'host', '-W', '2', '-t', 'MX', host, :err => IO::NULL)
      return false unless status.success?

      output.each_line do |line|
        line.chomp!
        if line.delete_prefix!(host) && line.delete_prefix!(' ') && re.match?(line)
          return true
        end
      end
    end

    false
  rescue Timeout::Error
    false
  end
  module_function :valid_mx_records?
end
