require 'capybara/rspec'

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :rack_test

# Capybaraのクッキー設定用ヘルパー
module CapybaraHelper
  def set_cookie(name, value)
    page.driver.browser.set_cookie("#{name}=#{value}")
  end
end

RSpec.configure do |config|
  config.include CapybaraHelper
end
