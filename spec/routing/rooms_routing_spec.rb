# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'rooms routes', type: :routing do
  it 'routes GET /join to rooms#find' do
    expect(get: '/join').to route_to(controller: 'rooms', action: 'find')
  end
end
