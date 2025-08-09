# Disable Host Authorization for production deployment
# This is necessary for Render.com and similar PaaS platforms

if Rails.env.production?
  Rails.application.configure do
    config.hosts.clear
  end
end
