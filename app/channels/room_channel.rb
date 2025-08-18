# frozen_string_literal: true

class RoomChannel < ApplicationCable::Channel
  def subscribed
    room_id = params[:room_id]
    Rails.logger.info "🔗 ActionCable: Client subscribed to room #{room_id} (connection: #{connection.request_id})"
    
    # ストリームを開始
    stream_from "room_#{room_id}"
    Rails.logger.info "📺 ActionCable: Started streaming for room_#{room_id}"
    
    # 接続確認のためのpingメッセージを送信
    transmit({ type: 'ping', message: 'ActionCable connected successfully', timestamp: Time.current.to_i })
    
    # 参加者一覧を送信
    participants_data = RoomRegistry.participant_list(room_id).map { |p| { name: p.name } }
    transmit({ type: 'participants', participants: participants_data })
    Rails.logger.info "👥 ActionCable: Sent #{participants_data.size} participants to room #{room_id}"
    
    # 最後の抽選結果があれば送信
    room = RoomRegistry.find_room(room_id)
    if room&.last_selection && room.last_selection[:selected]
      last = room.last_selection
      transmit({ type: 'selection', selected: last[:selected], count: last[:count] })
      Rails.logger.info "🎯 ActionCable: Sent last selection to room #{room_id}"
    end
  rescue => e
    Rails.logger.error "❌ ActionCable subscription error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def unsubscribed
    Rails.logger.info "🔌 ActionCable: Client unsubscribed"
    # パーティシパントの離脱（自動判定は難しいので今回は何もしない）
  end
end
