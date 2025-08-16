# frozen_string_literal: true

# ActionCable ブロードキャスト機能を管理するサービス
class ActionCableBroadcastService
  def self.broadcast_participants_update(room_id)
    new(room_id).broadcast_participants_update
  end

  def self.broadcast_selection_update(room_id, selected, count)
    new(room_id).broadcast_selection_update(selected, count)
  end

  def initialize(room_id)
    @room_id = room_id
  end

  def broadcast_participants_update
    participants_data = participants_for_broadcast
    broadcast_message(
      type: 'participants',
      participants: participants_data
    )
    log_broadcast('participants', participants_data.size)
  rescue => e
    log_broadcast_error(e)
  end

  def broadcast_selection_update(selected, count)
    selection_data = selected.map { |p| { name: p.name } }
    broadcast_message(
      type: 'selection',
      selected: selection_data,
      count: count
    )
    log_broadcast('selection', selection_data.size)
  rescue => e
    log_broadcast_error(e)
  end

  private

  def participants_for_broadcast
    RoomRegistry.participant_list(@room_id).map { |p| { name: p.name } }
  end

  def broadcast_message(message)
    ActionCable.server.broadcast("room_#{@room_id}", message)
  end

  def log_broadcast(type, count)
    Rails.logger.info "📡 ActionCable: Broadcasted #{type} update for room #{@room_id} (#{count} items)"
  end

  def log_broadcast_error(error)
    Rails.logger.warn "⚠️  ActionCable broadcast failed: #{error.message}"
  end
end
