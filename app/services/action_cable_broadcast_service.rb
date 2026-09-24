# frozen_string_literal: true

# ActionCable ブロードキャスト機能を管理するサービス
class ActionCableBroadcastService
  def self.broadcast_participants_update(room_id)
    new(room_id).broadcast_participants_update
  end

  def self.broadcast_selection_update(room_id, selection, history)
    new(room_id).broadcast_selection_update(selection, history)
  end

  # ブロードキャスト/JSON/チャンネル送信で共通利用する、トークンを含まない抽選履歴の圧縮表現
  def self.compact_history(history)
    (history || []).map { |entry| { id: entry[:id], number: entry[:number], selected: entry[:selected] } }
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

  def broadcast_selection_update(selection, history)
    broadcast_message(
      type: 'selection',
      id: selection[:id],
      selected: selection[:selected],
      count: selection[:count],
      animate: true,
      history: self.class.compact_history(history)
    )
    log_broadcast('selection', selection[:selected].size)
  rescue => e
    log_broadcast_error(e)
  end

  private

  def participants_for_broadcast
    RoomRegistry.participant_list(@room_id).map { |p| { id: p.id, name: p.name } }
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
