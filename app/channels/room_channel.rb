# frozen_string_literal: true

class RoomChannel < ApplicationCable::Channel
  def subscribed
    room_id = params[:room_id]
    stream_from "room_#{room_id}"
    transmit(type: 'participants', participants: RoomRegistry.participant_list(room_id).map { |p| { name: p.name } })
    last = RoomRegistry.find_room(room_id)&.last_selection
    transmit(type: 'selection', selected: last[:selected], count: last[:count]) if last
  end

  def unsubscribed
    # パーティシパントの離脱（自動判定は難しいので今回は何もしない）
  end
end
