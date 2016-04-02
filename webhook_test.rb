require 'bundler/setup'

$:.unshift File.expand_path('..', __FILE__)
require 'app/controllers/app_controller'

puts 'Running webhook.'
hook_path = "/hooks/trunk/#{ENV['OUTGOING_HOOK_PATH']}"

Webhook.pod_created = [
]
Webhook.version_created = [
]
Webhook.spec_updated = [
  'http://requestb.in/1jkavzk1' # Testing
]

Webhook.enable
sleep 5

20.times do
  Webhook.spec_updated(
    Time.now,
    'NSAttributedString+CCLFormat',
    '1.0.1',
    '9745cbb65ebb35c4507aec902c93c9174953369f',
    'https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/NSAttributedString+CCLFormat/1.0.1/NSAttributedString+CCLFormat.podspec.json',
  )
end
