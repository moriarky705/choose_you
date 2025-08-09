ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Disable host authorization for production deployment
ENV["RAILS_DISABLE_HOST_AUTHORIZATION"] = "1" if ENV["RAILS_ENV"] == "production"
