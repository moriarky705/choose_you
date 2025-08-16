require 'rails_helper'

RSpec.describe RoomChannel, type: :channel do
  let(:owner_name) { 'テストオーナー' }
  let!(:room) { RoomRegistry.create_room(owner_name: owner_name).first }
  let!(:participant) { RoomRegistry.add_participant(room_id: room.id, name: '参加者') }

  before do
    stub_connection request_id: 'test_connection_id'
  end

  describe '#subscribed' do
    it 'ルームのストリームに接続する' do
      subscribe(room_id: room.id)
      
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("room_#{room.id}")
    end

    it '参加者リストを送信する' do
      expect { subscribe(room_id: room.id) }.to have_broadcasted_to("room_#{room.id}").with(
        hash_including(
          type: 'participants',
          participants: array_including(
            hash_including(name: owner_name),
            hash_including(name: '参加者')
          )
        )
      )
    end

    it 'ping メッセージを送信する' do
      expect { subscribe(room_id: room.id) }.to have_broadcasted_to("room_#{room.id}").with(
        hash_including(
          type: 'ping',
          message: 'ActionCable connected successfully'
        )
      )
    end

    context '最後の抽選結果がある場合' do
      before do
        RoomRegistry.select_random(room_id: room.id, count: 1)
      end

      it '最後の抽選結果を送信する' do
        expect { subscribe(room_id: room.id) }.to have_broadcasted_to("room_#{room.id}").with(
          hash_including(
            type: 'selection',
            count: 1
          )
        )
      end
    end
  end

  describe '#unsubscribed' do
    it 'ログを出力する' do
      subscribe(room_id: room.id)
      
      expect(Rails.logger).to receive(:info).with("🔌 ActionCable: Client unsubscribed")
      unsubscribe
    end
  end

  describe 'ブロードキャストメッセージの受信' do
    before do
      subscribe(room_id: room.id)
    end

    it '参加者更新メッセージを受信できる' do
      expect {
        ActionCable.server.broadcast("room_#{room.id}", {
          type: 'participants',
          participants: [{ name: 'New Participant' }]
        })
      }.to have_broadcasted_to("room_#{room.id}").with(
        hash_including(
          type: 'participants',
          participants: [{ name: 'New Participant' }]
        )
      )
    end

    it '抽選結果メッセージを受信できる' do
      expect {
        ActionCable.server.broadcast("room_#{room.id}", {
          type: 'selection',
          selected: [{ name: owner_name }],
          count: 1
        })
      }.to have_broadcasted_to("room_#{room.id}").with(
        hash_including(
          type: 'selection',
          selected: [{ name: owner_name }],
          count: 1
        )
      )
    end
  end
end
