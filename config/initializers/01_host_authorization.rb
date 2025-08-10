# Rails Host Authorization bypass for production
# This file ensures host authorization is completely disabled in production

Rails.application.configure do
  if Rails.env.production?
    # Multiple approaches to disable host authorization
    config.hosts.clear
    config.host_authorization = false
    config.host_authorization = { exclude: ->(request) { true } }
    
    # Also set the Rails internal environment variable
    ENV['RAILS_DISABLE_HOST_AUTHORIZATION'] = '1'
  end
end if defined?(Rails) && Rails.application
