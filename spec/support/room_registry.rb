# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    RoomRegistry.instance_variable_set(:@service, InMemoryRoomService.new)
  end
end
