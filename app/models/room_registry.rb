# frozen_string_literal: true

require 'securerandom'
require 'thread'

# インメモリで部屋と参加者を管理するレジストリ（プロセス内のみで永続化なし）
class RoomRegistry
  Room = Struct.new(:id, :owner_token, :owner_name, :participants, :created_at, :last_selection, keyword_init: true)
  Participant = Struct.new(:token, :name, :joined_at, keyword_init: true)

  class << self
    def instance
      @instance ||= new
    end

    # 委譲メソッド群を動的に定義
    %i[create_room find_room add_participant participant_list select_random].each do |method_name|
      define_method(method_name) do |*args, **kwargs|
        instance.public_send(method_name, *args, **kwargs)
      end
    end
  end

  def initialize
    @rooms = {}
    @mutex = Mutex.new
  end

  def create_room(owner_name:)
    room_id = generate_unique_room_id
    owner_token = generate_token(16)
    
    room = Room.new(
      id: room_id,
      owner_token: owner_token,
      owner_name: owner_name,
      participants: [],
      created_at: Time.now,
      last_selection: nil
    )
    
    store_room(room_id, room)
    [room, owner_token]
  end

  def find_room(id)
    @rooms[id]
  end

  def add_participant(room_id:, name:)
    room = find_room(room_id)
    return unless room
    
    participant = create_participant(name)
    add_participant_to_room(room, participant)
    participant
  end

  def participant_list(room_id)
    room = find_room(room_id)
    return [] unless room
    
    build_complete_participant_list(room)
  end

  def select_random(room_id:, count:)
    room = find_room(room_id)
    return [] unless room
    
    all_participants = participant_list(room_id)
    selected_count = [count, all_participants.size].min
    selected = all_participants.sample(selected_count)
    
    update_last_selection(room, selected, count)
    selected
  end

  private

  def generate_unique_room_id
    loop do
      id = SecureRandom.alphanumeric(6).downcase
      return id unless @rooms.key?(id)
    end
  end

  def generate_token(length)
    SecureRandom.hex(length)
  end

  def store_room(room_id, room)
    @mutex.synchronize { @rooms[room_id] = room }
  end

  def create_participant(name)
    Participant.new(
      token: generate_token(12),
      name: name,
      joined_at: Time.now
    )
  end

  def add_participant_to_room(room, participant)
    @mutex.synchronize { room.participants << participant }
  end

  def build_complete_participant_list(room)
    owner_as_participant = Participant.new(
      token: room.owner_token,
      name: room.owner_name,
      joined_at: room.created_at
    )
    
    [*room.participants, owner_as_participant]
  end

  def update_last_selection(room, selected, count)
    room.last_selection = {
      at: Time.now,
      count: count,
      selected: selected.map { |p| { name: p.name } }
    }
  end
end
