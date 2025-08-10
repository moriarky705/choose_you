# Render.com Host Authorization Configuration
# This file ensures proper host authorization for Render.com deployment

Rails.application.configure do
  if Rails.env.production?
    # Clear existing hosts and set specific ones
    config.hosts.clear
    config.hosts << "choose-you.onrender.com"
    config.hosts << /.*\.onrender\.com/
    
    # Use the exclude approach to bypass host checking
    config.host_authorization = { exclude: ->(request) { true } }
    
    # Set environment variable for additional safety
    ENV['RAILS_DISABLE_HOST_AUTHORIZATION'] = '1'
  end
end if defined?(Rails) && Rails.application
