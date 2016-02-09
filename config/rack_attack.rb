require 'active_support'
require 'dalli'

def hourly_limit
  ENV['HOURLY_RATE_LIMIT'].try(:to_i) || 100
end

def extract_required_environment_variable(key)
  unless ENV.key? key
    raise ArgumentError, "Required `#{key}` not set in environment"
  end

  ENV[key]
end

def memcache_hosts
  extract_required_environment_variable('RATE_LIMIT_MEMCACHE_HOSTS').split(',')
end

def memcache_username
  extract_required_environment_variable('RATE_LIMIT_MEMCACHE_USERNAME')
end

def memcache_password
  extract_required_environment_variable('RATE_LIMIT_MEMCACHE_PASSWORD')
end

options = {
  :namespace => 'cocoapods',
  :compress => true,
  :username => memcache_username,
  :password => memcache_password,
}

Rack::Attack.cache.store = Dalli::Client.new(memcache_hosts, options)
# Always allow requests from localhost
# (blacklist & throttles are skipped)
Rack::Attack.whitelist('allow from localhost') do |req|
  # Requests are allowed if the return value is truthy
  '127.0.0.1' == req.ip || '::1' == req.ip
end

Rack::Attack.throttle('req/ip', :limit => hourly_limit, :period => 1.hour) do |req|
  req.if if req.path.match(%r{/api/pods/.*})
end

Rack::Attack.throttled_response = lambda do |_|
  # Using 503 because it may make attacker think that they have successfully
  # DOSed the site. Rack::Attack returns 429 for throttling by default
  [503, {}, []]
end
