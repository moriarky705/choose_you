# Render.com Host Authorization Configuration
# This file ensures Host Authorization is completely disabled for Render.com deployment

# Disable at the earliest possible stage
Rails.application.configure do
  if Rails.env.production?
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
  end
end if defined?(Rails) && Rails.application
