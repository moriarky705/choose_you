require 'rails_helper'

RSpec.describe RoomsController, type: :controller do
  include ActionCable::TestHelper

  describe 'GET #new' do
    it 'ルーム作成画面を表示する' do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #create' do
    let(:owner_name) { 'テストオーナー' }

    it 'ルームを作成してリダイレクトする' do
      post :create, params: { owner_name: owner_name }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{/rooms/[a-z0-9]{6}})

      room_id = response.location.match(%r{/rooms/([a-z0-9]{6})})[1]
      expect(RoomRegistry.room_exists?(room_id)).to be true
    end

    it 'オーナートークンをクッキーに保存する' do
      post :create, params: { owner_name: owner_name }
      room_id = response.location.match(%r{/rooms/([a-z0-9]{6})})[1]
      expect(cookies.signed["owner_token_#{room_id}"]).to be_present
    end

    it 'リダイレクト先のURLにowner_tokenを含めない' do
      post :create, params: { owner_name: owner_name }
      expect(response.location).not_to include('owner_token')
    end

    it '複数のルームを作成してもそれぞれのオーナー権限を保持する' do
      post :create, params: { owner_name: owner_name }
      first_room_id = response.location.match(%r{/rooms/([a-z0-9]{6})})[1]

      post :create, params: { owner_name: owner_name }

      get :show, params: { id: first_room_id }
      expect(assigns(:owner_view)).to be true
    end

    context 'パラメータが不正な場合' do
      it 'ActionController::ParameterMissingが発生する' do
        expect {
          post :create, params: {}
        }.to raise_error(ActionController::ParameterMissing)
      end
    end
  end

  describe 'GET #show' do
    render_views

    let(:owner_name) { 'テストオーナー' }
    let!(:room) { RoomRegistry.create_room(owner_name: owner_name).first }

    context '存在しないルームの場合' do
      it 'ルートパスにリダイレクトする' do
        get :show, params: { id: 'nonexistent' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('部屋が見つかりません。部屋が削除されたか、セッションが期限切れの可能性があります。')
      end
    end

    context 'オーナーとしてアクセスする場合' do
      before do
        cookies.signed["owner_token_#{room.id}"] = room.owner_token
      end

      it 'ルーム画面を表示する' do
        get :show, params: { id: room.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:owner_view)).to be true
        expect(assigns(:participants)).to be_present
      end

      it 'オーナーIDをdata-room-self-id-valueに含める' do
        get :show, params: { id: room.id }
        expect(response.body).to include("data-room-self-id-value=\"#{room.owner_id}\"")
      end

      it '抽選人数パラメータを保持する' do
        get :show, params: { id: room.id, count: '3' }
        expect(assigns(:last_count)).to eq(3)
      end
    end

    context '参加者としてアクセスする場合' do
      let!(:participant) { RoomRegistry.add_participant(room_id: room.id, name: '参加者') }

      before do
        cookies.signed["participant_token_#{room.id}"] = participant.token
      end

      it 'ルーム画面を表示する' do
        get :show, params: { id: room.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:owner_view)).to be false
        expect(assigns(:participant)).to be_present
        expect(assigns(:participant).name).to eq(participant.name)
      end

      it '参加者IDをdata-room-self-id-valueに含め、自分の行に（あなた）と表示する' do
        get :show, params: { id: room.id }
        expect(response.body).to include("data-room-self-id-value=\"#{participant.id}\"")
        expect(response.body).to include('（あなた）')
      end
    end

    context '未認証でアクセスする場合' do
      it '参加フォームを表示する' do
        get :show, params: { id: room.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:join_form)
      end
    end

    context 'owner_tokenパラメータ付きの旧リンクでアクセスする場合' do
      it '有効なトークンならクッキーを設定してリダイレクトする' do
        get :show, params: { id: room.id, owner_token: room.owner_token }
        expect(response).to redirect_to(room_path(room.id))
        expect(cookies.signed["owner_token_#{room.id}"]).to eq(room.owner_token)
      end

      it '無効なトークンならクッキーを設定せずリダイレクトする' do
        get :show, params: { id: room.id, owner_token: 'invalid_token' }
        expect(response).to redirect_to(room_path(room.id))
        expect(cookies.signed["owner_token_#{room.id}"]).to be_nil
      end
    end

    context 'participant_tokenパラメータ付きの旧リンクでアクセスする場合' do
      let!(:participant) { RoomRegistry.add_participant(room_id: room.id, name: '参加者') }

      it '有効なトークンならクッキーを設定してリダイレクトする' do
        get :show, params: { id: room.id, participant_token: participant.token }
        expect(response).to redirect_to(room_path(room.id))
        expect(cookies.signed["participant_token_#{room.id}"]).to eq(participant.token)
      end
    end
  end

  describe 'POST #join' do
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { RoomRegistry.create_room(owner_name: owner_name).first }
    let(:participant_name) { '新しい参加者' }

    it '参加者を追加してルームにリダイレクトする' do
      expect {
        post :join, params: { id: room.id, name: participant_name }
      }.to change { RoomRegistry.participant_list(room.id).size }.from(1).to(2)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(room_path(room.id))
    end

    it 'リダイレクト先のURLにparticipant_tokenを含めない' do
      post :join, params: { id: room.id, name: participant_name }
      expect(response.location).not_to include('participant_token')
      expect(response.location).to end_with(room_path(room.id))
    end

    it '参加者トークンをクッキーに保存する' do
      post :join, params: { id: room.id, name: participant_name }
      expect(cookies.signed["participant_token_#{room.id}"]).to be_present
    end

    context '既に参加している場合' do
      let!(:participant) { RoomRegistry.add_participant(room_id: room.id, name: participant_name) }

      before do
        cookies.signed["participant_token_#{room.id}"] = participant.token
      end

      it '重複参加せずにリダイレクトする' do
        expect {
          post :join, params: { id: room.id, name: participant_name }
        }.not_to change { RoomRegistry.participant_list(room.id).size }

        expect(response).to redirect_to(room_path(room.id))
      end
    end

    context 'パラメータが不正な場合' do
      it 'ActionController::ParameterMissingが発生する' do
        expect {
          post :join, params: { id: room.id }
        }.to raise_error(ActionController::ParameterMissing)
      end
    end
  end

  describe 'POST #select' do
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { RoomRegistry.create_room(owner_name: owner_name).first }
    let!(:participant) { RoomRegistry.add_participant(room_id: room.id, name: '参加者') }

    before do
      cookies.signed["owner_token_#{room.id}"] = room.owner_token
    end

    it '抽選を実行してリダイレクトする' do
      post :select, params: { id: room.id, count: '1' }

      expect(response).to redirect_to(room_path(room.id, count: 1))
      expect(room.last_selection).to be_present
      expect(room.last_selection[:count]).to eq(1)
    end

    it '指定した人数で抽選する' do
      post :select, params: { id: room.id, count: '2' }

      expect(room.last_selection[:count]).to eq(2)
      expect(room.last_selection[:selected].size).to eq(2)
    end

    context 'オーナーでない場合' do
      before do
        cookies.signed["owner_token_#{room.id}"] = 'invalid_token'
      end

      it 'Forbiddenエラーを返す' do
        post :select, params: { id: room.id, count: '1' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'パラメータが不正な場合' do
      it 'countパラメータなしでもリダイレクトされる' do
        post :select, params: { id: room.id }
        expect(response).to have_http_status(:found)
      end
    end

    context 'JSON形式でリクエストする場合' do
      it '抽選を実行してokと抽選結果を返す' do
        expect {
          post :select, params: { id: room.id, count: '1' }, format: :json
        }.to have_broadcasted_to("room_#{room.id}").with(hash_including('type' => 'selection', 'animate' => true))

        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['ok']).to be true
        expect(json['selection']['id']).to be_present
        expect(json['selection']['count']).to eq(1)
        expect(json['selection']['selected']).to all(include('id', 'name'))
      end

      it 'countが0の場合はエラーを返す' do
        post :select, params: { id: room.id, count: '0' }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to be_present
      end

      it '参加者数より多い場合はエラーを返す' do
        post :select, params: { id: room.id, count: '99' }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to eq('抽選対象(2人)以下の人数を指定してください')
      end

      it 'JSON成功レスポンスにhistoryを含める' do
        post :select, params: { id: room.id, count: '1' }, format: :json

        json = JSON.parse(response.body)
        expect(json['history']).to be_present
        expect(json['history'].first).to include('id', 'number', 'selected')
        expect(json['history'].first['selected']).to all(include('id', 'name'))
      end

      it 'include_owner: "0"の場合オーナーを抽選対象から除外する' do
        post :select, params: { id: room.id, count: '1', include_owner: '0' }, format: :json

        json = JSON.parse(response.body)
        selected_ids = json['selection']['selected'].map { |s| s['id'] }
        expect(selected_ids).not_to include(room.owner_id)
      end

      it 'exclude_winners: "1"の場合、前回の当選者を抽選対象から除外する' do
        post :select, params: { id: room.id, count: '1' }, format: :json
        first_winner_id = JSON.parse(response.body)['selection']['selected'].first['id']

        post :select, params: { id: room.id, count: '1', exclude_winners: '1' }, format: :json
        second_selected_ids = JSON.parse(response.body)['selection']['selected'].map { |s| s['id'] }

        expect(second_selected_ids).not_to include(first_winner_id)
      end

      it 'include_ownerパラメータがない場合はオーナーを抽選対象に含める（後方互換）' do
        post :select, params: { id: room.id, count: '2' }, format: :json

        selected_ids = JSON.parse(response.body)['selection']['selected'].map { |s| s['id'] }
        expect(selected_ids).to include(room.owner_id)
      end

      it '抽選対象が空の場合422を返す' do
        solo_room, solo_token = RoomRegistry.create_room(owner_name: 'ソロオーナー')
        cookies.signed["owner_token_#{solo_room.id}"] = solo_token

        post :select, params: { id: solo_room.id, count: '1', include_owner: '0' }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to eq('抽選対象の参加者がいません')
      end

      it '検証後の抽選でプールが変化して空配列が返った場合は422を返しブロードキャストしない（競合対策）' do
        allow(RoomRegistry).to receive(:select_random).and_return([])

        expect {
          post :select, params: { id: room.id, count: '1' }, format: :json
        }.not_to have_broadcasted_to("room_#{room.id}")

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to eq('抽選できませんでした。もう一度お試しください')
      end
    end
  end

  describe 'GET #updates' do
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { RoomRegistry.create_room(owner_name: owner_name).first }
    let!(:participant) { RoomRegistry.add_participant(room_id: room.id, name: '参加者') }

    before do
      RoomRegistry.select_random(room_id: room.id, count: 1)
    end

    it 'JSON形式で更新データを返す' do
      get :updates, params: { id: room.id }, format: :json

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('application/json')

      json = JSON.parse(response.body)
      expect(json['participants']).to be_present
      expect(json['participants']).to all(include('id', 'name'))
      expect(json['selection']).to be_present
      expect(json['selection']['id']).to be_present
      expect(json['selection']['count']).to eq(1)
      expect(json['history']).to be_present
      expect(json['history'].first).to include('id', 'number', 'selected')
      expect(json['history'].first['selected']).to all(include('id', 'name'))
    end

    it 'トークンを含まない' do
      get :updates, params: { id: room.id }, format: :json

      expect(response.body).not_to include(room.owner_token)
      expect(response.body).not_to include(participant.token)
    end

    context '存在しないルームの場合' do
      it '404エラーを返す' do
        get :updates, params: { id: 'nonexistent' }, format: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'private methods' do
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { RoomRegistry.create_room(owner_name: owner_name).first }

    describe '#owner_token_matches?' do
      it '旧仕様のグローバルなowner_tokenクッキーでもオーナー権限が有効' do
        cookies.signed[:owner_token] = room.owner_token
        get :show, params: { id: room.id }
        expect(assigns(:owner_view)).to be true
      end

      it 'オーナートークンが一致しない場合falseを返す' do
        cookies.signed["owner_token_#{room.id}"] = 'invalid_token'
        get :show, params: { id: room.id }
        expect(response).to render_template(:join_form)
      end
    end

    describe '#participant_cookie_key' do
      it '正しいクッキーキーを生成する' do
        controller = described_class.new
        key = controller.send(:participant_cookie_key, room.id)
        expect(key).to eq("participant_token_#{room.id}")
      end
    end
  end
end
