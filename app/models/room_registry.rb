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

    def create_room(owner_name:)
      instance.create_room(owner_name:)
    end

    def find_room(id)
      instance.find_room(id)
    end

    def add_participant(room_id:, name:)
      instance.add_participant(room_id:, name:)
    end

    def participant_list(room_id)
      instance.participant_list(room_id)
    end

    def select_random(room_id:, count:)
      instance.select_random(room_id:, count:)
    end
  end

  def initialize
    @rooms = {}
    @mutex = Mutex.new
  end

  def create_room(owner_name:)
    room_id = generate_room_id
    owner_token = SecureRandom.hex(16)
    room = Room.new(id: room_id, owner_token:, owner_name:, participants: [], created_at: Time.now, last_selection: nil)
    @mutex.synchronize { @rooms[room_id] = room }
    [room, owner_token]
  end

  def find_room(id)
    @rooms[id]
  end

  def add_participant(room_id:, name:)
    room = find_room(room_id)
    return unless room
    token = SecureRandom.hex(12)
    participant = Participant.new(token:, name:, joined_at: Time.now)
    @mutex.synchronize { room.participants << participant }
    participant
  end

  def participant_list(room_id)
    room = find_room(room_id)
    return [] unless room
    [*room.participants, Participant.new(token: room.owner_token, name: room.owner_name, joined_at: room.created_at)]
  end

  def select_random(room_id:, count:)
    room = find_room(room_id)
    return [] unless room
    all = participant_list(room_id)
    selected = all.sample([count, all.size].min)
    room.last_selection = { at: Time.now, count:, selected: selected.map { |p| { name: p.name } } }
    selected
  end

  private

  def generate_room_id
    loop do
      id = SecureRandom.alphanumeric(6).downcase
      return id unless @rooms.key?(id)
    end
  end
end
