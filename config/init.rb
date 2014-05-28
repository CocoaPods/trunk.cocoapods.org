# -- General ------------------------------------------------------------------

ROOT = File.expand_path('../../', __FILE__)
$LOAD_PATH.unshift File.join(ROOT, 'lib')

ENV['RACK_ENV'] ||= 'production'
ENV['DATABASE_URL'] ||= "postgres://localhost/trunk_cocoapods_org_#{ENV['RACK_ENV']}"

if ENV['RACK_ENV'] == 'development'
  require 'sinatra/reloader'
end

require 'i18n'
I18n.enforce_available_locales = false
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/date/calculations'

require 'active_support/core_ext/time/zones'
require 'active_support/core_ext/time/calculations'
Time.zone = 'UTC'

# Explicitly load the C-ext version.
require 'json/ext'

if !defined?(IRB) && ENV['RACK_ENV'] == 'production'
  require 'newrelic_rpm'
end

# require 'new_relic/rack/developer_mode'
# use NewRelic::Rack::DeveloperMode

# -- Webhooks -----------------------------------------------------------------

require 'lib/webhook'

# List of attached web hook URLs.
#
# Warning: Do not add non-existing domains.
#
if ENV['WEBHOOKS_ENABLED'] == 'true'
  hook_path = "/hooks/trunk/#{ENV['OUTGOING_HOOK_PATH']}"

  Webhook.pod_created = [
  ]
  Webhook.version_created = [
  ]
  Webhook.spec_updated = [
    "http://199.229.252.197:4567#{hook_path}", # CocoaDocs
    "http://search.cocoapods.org#{hook_path}"
  ]

  Webhook.enable
end

# -- Logging ------------------------------------------------------------------

require 'logger'
require 'fileutils'

if ENV['TRUNK_APP_LOG_TO_STDOUT']
  STDOUT.sync = true
  STDERR.sync = true
  TRUNK_APP_LOGGER = Logger.new(STDOUT)
  TRUNK_APP_LOGGER.level = Logger::INFO
else
  FileUtils.mkdir_p(File.join(ROOT, 'log'))
  TRUNK_APP_LOG_FILE = File.new(File.join(ROOT, "log/#{ENV['RACK_ENV']}.log"), 'a+')
  TRUNK_APP_LOG_FILE.sync = true
  TRUNK_APP_LOGGER = Logger.new(TRUNK_APP_LOG_FILE)
  TRUNK_APP_LOGGER.level = Logger::DEBUG
end

# -- Database -----------------------------------------------------------------

require 'sequel'
require 'pg'

db_loggers = []
db_loggers << TRUNK_APP_LOGGER # TODO: For now also enable DB logger in production. unless ENV['RACK_ENV'] == 'production'
DB = Sequel.connect(ENV['DATABASE_URL'], :loggers => db_loggers)
DB.timezone = :utc
Sequel.extension :core_extensions, :migration

class << DB
  # Save point is needed in testing, because tests already run in a
  # transaction, which means the transaction would be re-used and we can't test
  # whether or the transaction has been rolled back.
  #
  # This is overridden in tests to do add a save point.
  alias_method :test_safe_transaction, :transaction
end

# -- Email --------------------------------------------------------------------

require 'mail'

if ENV['RACK_ENV'] != 'production'
  module Pod
    module TrunkApp
      class TestMailer < Mail::TestMailer
        def deliver!(mail)
          super
          TRUNK_APP_LOGGER.debug(mail.to_s)
          mail
        end
      end
    end
  end
end

Mail.defaults do
  case ENV['RACK_ENV']
  when 'production'
    delivery_method :smtp,
                    :address => 'smtp.sendgrid.net',
                    :port => '587',
                    :domain => 'heroku.com',
                    :user_name => ENV['SENDGRID_USERNAME'],
                    :password => ENV['SENDGRID_PASSWORD'],
                    :authentication => :plain,
                    :enable_starttls_auto => true

  else
    delivery_method Pod::TrunkApp::TestMailer
  end
end

# -- Console ------------------------------------------------------------------

if defined?(IRB)
  puts "[!] Loading `#{ENV['RACK_ENV']}' environment."
  Dir.chdir(ROOT) do
    Dir.glob('app/models/*.rb').each do |model|
      require model[0..-4]
    end
  end
  include Pod::TrunkApp
end
