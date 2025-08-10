# Render.com Host Authorization Configuration
# This file ensures Host Authorization is completely disabled for ALL environments

# Disable at the earliest possible stage - NO environment check
Rails.application.configure do
  # Remove the middleware entirely
  config.middleware.delete ActionDispatch::HostAuthorization if defined?(ActionDispatch::HostAuthorization)
  
  # Clear existing hosts and set specific ones (backup)
  config.hosts.clear
  config.hosts << "choose-you.onrender.com"
  config.hosts << /.*\.onrender\.com/
  
  # Use the exclude approach to bypass host checking (backup)
  config.host_authorization = { exclude: ->(request) { true } }
  
  # Set environment variable for additional safety
  ENV['RAILS_DISABLE_HOST_AUTHORIZATION'] = '1'
end if defined?(Rails) && Rails.application
