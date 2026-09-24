# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'rooms routes', type: :routing do
  it 'routes GET /join to rooms#find' do
    expect(get: '/join').to route_to(controller: 'rooms', action: 'find')
  end

  it 'routes POST /rooms/:id/leave to rooms#leave' do
    expect(post: '/rooms/abc123/leave').to route_to(controller: 'rooms', action: 'leave', id: 'abc123')
  end

  it 'routes DELETE /rooms/:id/participants/:participant_id to rooms#remove_participant' do
    expect(delete: '/rooms/abc123/participants/xyz789').to route_to(
      controller: 'rooms', action: 'remove_participant', id: 'abc123', participant_id: 'xyz789'
    )
  end
end
