# Disable Host Authorization for production deployment
# This is necessary for Render.com and similar PaaS platforms

if Rails.env.production?
  Rails.application.configure do
    config.hosts.clear
    # Also disable using Rails internal environment variable
    config.force_ssl = false
    config.host_authorization = { exclude: ->(request) { true } }
  end
end

# Set environment variable to disable host authorization globally
ENV["RAILS_DISABLE_HOST_AUTHORIZATION"] = "1" if Rails.env.production?
