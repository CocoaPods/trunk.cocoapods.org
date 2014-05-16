require 'lib/webhook'

# List of attached web hook URLs.
#
# Warning: Do not add non-existing domains.
#
garbled_hook_path = ENV['OUTGOING_HOOK_PATH']
Webhook.urls = [
  # "http://cocoadocs.org/hooks/trunk/#{garbled_hook_path}",
  # "http://metrics.cocoapods.org/hooks/trunk/#{garbled_hook_path}",
  "http://search.cocoapods.org/hooks/trunk/#{garbled_hook_path}"
]

Webhook.run
