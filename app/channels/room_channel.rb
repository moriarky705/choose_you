# frozen_string_literal: true

class RoomChannel < ApplicationCable::Channel
  def subscribed
    room_id = params[:room_id]
    Rails.logger.info "🔗 ActionCable: Client subscribed to room #{room_id}"
    
    stream_from "room_#{room_id}"
    
    # 参加者一覧を送信
    participants_data = RoomRegistry.participant_list(room_id).map { |p| { name: p.name } }
    transmit({ type: 'participants', participants: participants_data })
    
    # 最後の抽選結果があれば送信
    room = RoomRegistry.find_room(room_id)
    if room&.last_selection
      last = room.last_selection
      transmit({ type: 'selection', selected: last[:selected], count: last[:count] })
    end
  end

  def unsubscribed
    Rails.logger.info "🔌 ActionCable: Client unsubscribed"
    # パーティシパントの離脱（自動判定は難しいので今回は何もしない）
  end
end
