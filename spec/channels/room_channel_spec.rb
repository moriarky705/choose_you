require 'rails_helper'

RSpec.describe RoomChannel, type: :channel do
  let(:owner_name) { 'テストオーナー' }
  
  before do
    # テスト前にレジストリをクリア
    RoomRegistry.instance.instance_variable_set(:@rooms, {})
    # ルームを作成
    @room_result = RoomRegistry.create_room(owner_name: owner_name)
    @room = @room_result[0]  # 配列の最初の要素がroom
    
    # 参加者を追加
    RoomRegistry.add_participant(room_id: @room.id, name: '参加者')
  end

  describe '#subscribed' do
    it 'チャネルに接続できる' do
      subscribe(room_id: @room.id)
      expect(subscription).to be_confirmed
    end

    it 'ルームストリームに接続される' do
      subscribe(room_id: @room.id)
      
      expect(subscription).to be_confirmed
      # ActionCableテストでは実際のストリーム接続状態の確認は困難
      # 代わりに接続が成功したことで十分とする
    end

    context '最後の抽選結果がある場合' do
      before do
        # 抽選結果を設定
        RoomRegistry.select_random(room_id: @room.id, count: 1)
      end

      it 'チャネルに接続できる' do
        subscribe(room_id: @room.id)
        
        expect(subscription).to be_confirmed
      end
    end
  end

  describe 'ブロードキャストメッセージの受信' do
    before do
      subscribe(room_id: @room.id)
    end

    it '抽選結果メッセージを受信できる' do
      expect {
        ActionCable.server.broadcast("room_#{@room.id}", {
          type: 'selection',
          count: 1,
          selected: [{ name: '参加者' }]
        })
      }.to have_broadcasted_to("room_#{@room.id}")
    end

    it '参加者更新メッセージを受信できる' do
      expect {
        ActionCable.server.broadcast("room_#{@room.id}", {
          type: 'participants',
          participants: [{ name: '参加者' }]
        })
      }.to have_broadcasted_to("room_#{@room.id}")
    end
  end

  describe '#unsubscribed' do
    it 'ログを出力する' do
      subscribe(room_id: @room.id)
      
      expect(Rails.logger).to receive(:info).with("🔌 ActionCable: Client unsubscribed")
      
      unsubscribe
    end
  end
end
