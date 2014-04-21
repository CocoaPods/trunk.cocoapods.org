$LOAD_PATH.unshift(File.expand_path('../../', __FILE__))
ENV['RACK_ENV'] ||= 'development'
require 'config/init'

# No need to ever verify email addresses with seeds.
require 'rfc822'
module RFC822
  def self.mx_records(address)
    [MXRecord.new(20, 'mail.example.com')]
  end
end

# Always load this
require 'db/seeds/production'

if ENV['RACK_ENV'] == 'development' && !ENV['SKIP_DEV_SEEDS']
  require 'db/seeds/development'
end
