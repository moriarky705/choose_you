# frozen_string_literal: true

require 'redis'
require 'json'
require 'securerandom'

# Redis バックエンドを使用した部屋管理サービス
class RedisRoomService
  Room = Struct.new(:id, :owner_token, :owner_name, :participants, :created_at, :last_selection, keyword_init: true)
  Participant = Struct.new(:token, :name, :joined_at, keyword_init: true)
  
  ROOM_KEY_PREFIX = 'room:'
  ROOM_EXPIRY = 24.hours.to_i
  
  def initialize
    @redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
  end
  
  def create_room(owner_name:)
    room_id = generate_unique_room_id
    owner_token = generate_token(16)
    
    room_data = {
      id: room_id,
      owner_token: owner_token,
      owner_name: owner_name,
      participants: [],
      created_at: Time.now.iso8601,
      last_selection: nil
    }
    
    store_room(room_id, room_data)
    Rails.logger.info "🏠 Redis: Created room: id=#{room_id}, owner=#{owner_name}"
    
    room = Room.new(**room_data.transform_keys(&:to_sym))
    room.created_at = Time.parse(room_data[:created_at])
    [room, owner_token]
  end
  
  def find_room(id)
    room_data = @redis.get(room_key(id))
    return nil unless room_data
    
    parsed_data = JSON.parse(room_data, symbolize_names: true)
    parsed_data[:participants] = parsed_data[:participants].map { |p| Participant.new(**p.transform_keys(&:to_sym)) }
    parsed_data[:created_at] = Time.parse(parsed_data[:created_at])
    
    room = Room.new(**parsed_data)
    Rails.logger.debug "🔍 Redis: Find room: id=#{id}, found=true"
    room
  rescue Redis::BaseError => e
    Rails.logger.error "❌ Redis error in find_room: #{e.message}"
    nil
  rescue JSON::ParserError => e
    Rails.logger.error "❌ JSON parse error in find_room: #{e.message}"
    nil
  end
  
  def add_participant(room_id:, name:)
    room = find_room(room_id)
    Rails.logger.info "👥 Redis: Adding participant: room_id=#{room_id}, name=#{name}, room_found=#{room.present?}"
    return nil unless room
    
    participant = Participant.new(
      token: generate_token(12),
      name: name,
      joined_at: Time.now
    )
    
    room.participants << participant
    store_room_object(room)
    Rails.logger.info "✅ Redis: Participant added successfully: #{participant.name}"
    participant
  rescue Redis::BaseError => e
    Rails.logger.error "❌ Redis error in add_participant: #{e.message}"
    nil
  end
  
  def participant_list(room_id)
    room = find_room(room_id)
    return [] unless room
    
    # オーナーと参加者を含む完全なリスト
    all_participants = [
      Participant.new(token: room.owner_token, name: room.owner_name, joined_at: room.created_at)
    ]
    all_participants.concat(room.participants)
    all_participants
  end
  
  def select_random(room_id:, count:)
    room = find_room(room_id)
    return [] unless room
    
    all_participants = participant_list(room_id)
    selected_count = [count, all_participants.size].min
    selected = all_participants.sample(selected_count)
    
    room.last_selection = {
      participants: selected.map { |p| { name: p.name } },
      count: count,
      selected_at: Time.now.iso8601
    }
    
    store_room_object(room)
    selected
  end
  
  def room_exists?(room_id)
    exists = @redis.exists?(room_key(room_id)) > 0
    Rails.logger.debug "🏠 Redis: Room exists check: id=#{room_id}, exists=#{exists}"
    exists
  rescue Redis::BaseError => e
    Rails.logger.error "❌ Redis error in room_exists?: #{e.message}"
    false
  end
  
  def cleanup_expired_rooms
    # Redis の TTL で自動的に期限切れになるため、手動クリーンアップは不要
    0
  end
  
  private
  
  def room_key(room_id)
    "#{ROOM_KEY_PREFIX}#{room_id}"
  end
  
  def store_room(room_id, room_data)
    room_json = room_data.to_json
    @redis.setex(room_key(room_id), ROOM_EXPIRY, room_json)
    Rails.logger.debug "💾 Redis: Stored room: #{room_id}"
  rescue Redis::BaseError => e
    Rails.logger.error "❌ Redis error in store_room: #{e.message}"
    raise
  end
  
  def store_room_object(room)
    room_data = {
      id: room.id,
      owner_token: room.owner_token,
      owner_name: room.owner_name,
      participants: room.participants.map { |p| p.to_h },
      created_at: room.created_at.iso8601,
      last_selection: room.last_selection
    }
    store_room(room.id, room_data)
  end
  
  def generate_unique_room_id
    loop do
      id = SecureRandom.alphanumeric(6).downcase
      return id unless room_exists?(id)
    end
  end
  
  def generate_token(length = 32)
    SecureRandom.urlsafe_base64(length)
  end
end
