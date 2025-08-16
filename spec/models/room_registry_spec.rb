require 'rails_helper'

RSpec.describe RoomRegistry, type: :model do
  let(:registry) { described_class.new }

  describe '#create_room' do
    let(:owner_name) { 'テストオーナー' }

    it 'ルームを作成してルームとオーナートークンを返す' do
      room, owner_token = registry.create_room(owner_name: owner_name)

      expect(room).to be_a(RoomRegistry::Room)
      expect(room.id).to be_a(String)
      expect(room.id.length).to eq(6)
      expect(room.owner_name).to eq(owner_name)
      expect(room.owner_token).to eq(owner_token)
      expect(room.participants).to eq([])
      expect(room.created_at).to be_a(Time)
      expect(room.last_selection).to be_nil
    end

    it '一意なルームIDを生成する' do
      room1, _ = registry.create_room(owner_name: owner_name)
      room2, _ = registry.create_room(owner_name: owner_name)

      expect(room1.id).not_to eq(room2.id)
    end

    it '一意なオーナートークンを生成する' do
      _, token1 = registry.create_room(owner_name: owner_name)
      _, token2 = registry.create_room(owner_name: owner_name)

      expect(token1).not_to eq(token2)
    end
  end

  describe '#find_room' do
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { registry.create_room(owner_name: owner_name).first }

    it '存在するルームを返す' do
      found_room = registry.find_room(room.id)
      expect(found_room).to eq(room)
    end

    it '存在しないルームの場合nilを返す' do
      found_room = registry.find_room('nonexistent')
      expect(found_room).to be_nil
    end
  end

  describe '#add_participant' do
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { registry.create_room(owner_name: owner_name).first }
    let(:participant_name) { 'テスト参加者' }

    it '参加者を追加して参加者オブジェクトを返す' do
      participant = registry.add_participant(room_id: room.id, name: participant_name)

      expect(participant).to be_a(RoomRegistry::Participant)
      expect(participant.name).to eq(participant_name)
      expect(participant.token).to be_a(String)
      expect(participant.joined_at).to be_a(Time)
    end

    it 'ルームの参加者リストに追加される' do
      expect {
        registry.add_participant(room_id: room.id, name: participant_name)
      }.to change { room.participants.size }.from(0).to(1)
    end

    it '存在しないルームの場合nilを返す' do
      participant = registry.add_participant(room_id: 'nonexistent', name: participant_name)
      expect(participant).to be_nil
    end

    it '複数の参加者を追加できる' do
      participant1 = registry.add_participant(room_id: room.id, name: '参加者1')
      participant2 = registry.add_participant(room_id: room.id, name: '参加者2')

      expect(room.participants).to include(participant1, participant2)
      expect(participant1.token).not_to eq(participant2.token)
    end
  end

  describe '#participant_list' do
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { registry.create_room(owner_name: owner_name).first }

    context 'オーナーのみの場合' do
      it 'オーナーを含むリストを返す' do
        participants = registry.participant_list(room.id)

        expect(participants.size).to eq(1)
        expect(participants.first.name).to eq(owner_name)
        expect(participants.first.token).to eq(room.owner_token)
      end
    end

    context '参加者がいる場合' do
      let!(:participant1) { registry.add_participant(room_id: room.id, name: '参加者1') }
      let!(:participant2) { registry.add_participant(room_id: room.id, name: '参加者2') }

      it 'オーナーと参加者を含むリストを返す' do
        participants = registry.participant_list(room.id)

        expect(participants.size).to eq(3)
        participant_names = participants.map(&:name)
        expect(participant_names).to include(owner_name, '参加者1', '参加者2')
      end
    end

    it '存在しないルームの場合空配列を返す' do
      participants = registry.participant_list('nonexistent')
      expect(participants).to eq([])
    end
  end

  describe '#select_random' do
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { registry.create_room(owner_name: owner_name).first }
    let!(:participant1) { registry.add_participant(room_id: room.id, name: '参加者1') }
    let!(:participant2) { registry.add_participant(room_id: room.id, name: '参加者2') }

    it '指定した人数を抽選する' do
      selected = registry.select_random(room_id: room.id, count: 2)

      expect(selected.size).to eq(2)
      expect(selected).to all(be_a(RoomRegistry::Participant))
    end

    it '参加者数より多い人数を指定した場合は全員を返す' do
      selected = registry.select_random(room_id: room.id, count: 10)

      expect(selected.size).to eq(3) # オーナー + 参加者2人
    end

    it 'last_selectionを更新する' do
      expect {
        registry.select_random(room_id: room.id, count: 1)
      }.to change { room.last_selection }.from(nil)

      expect(room.last_selection[:count]).to eq(1)
      expect(room.last_selection[:at]).to be_a(Time)
      expect(room.last_selection[:selected]).to be_a(Array)
    end

    it '存在しないルームの場合空配列を返す' do
      selected = registry.select_random(room_id: 'nonexistent', count: 1)
      expect(selected).to eq([])
    end
  end

  describe 'クラスメソッド' do
    it 'singletonインスタンスとして動作する' do
      expect(described_class.instance).to be_a(described_class)
      expect(described_class.instance).to eq(described_class.instance)
    end

    it 'クラスメソッドがインスタンスメソッドに委譲される' do
      owner_name = 'テストオーナー'
      
      room, token = described_class.create_room(owner_name: owner_name)
      expect(room.owner_name).to eq(owner_name)
      
      found_room = described_class.find_room(room.id)
      expect(found_room).to eq(room)
      
      participant = described_class.add_participant(room_id: room.id, name: '参加者')
      expect(participant.name).to eq('参加者')
      
      participants = described_class.participant_list(room.id)
      expect(participants.size).to eq(2)
      
      selected = described_class.select_random(room_id: room.id, count: 1)
      expect(selected.size).to eq(1)
    end
  end
end
