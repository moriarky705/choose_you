require 'rails_helper'

RSpec.describe RoomsController, type: :controller do
  let(:room_registry) { RoomRegistry.instance }
  
  before do
    # テスト前にレジストリをクリア
    room_registry.instance_variable_set(:@rooms, {})
  end

  describe 'GET #new' do
    it 'ルーム作成画面を表示する' do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #create' do
    let(:owner_name) { 'テストオーナー' }

    it 'ルームを作成してリダイレクトする' do
      expect {
        post :create, params: { owner_name: owner_name }
      }.to change { room_registry.instance_variable_get(:@rooms).size }.from(0).to(1)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{/rooms/[a-z0-9]{6}})
    end

    it 'オーナートークンをクッキーに保存する' do
      post :create, params: { owner_name: owner_name }
      expect(cookies.signed[:owner_token]).to be_present
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
    let(:owner_name) { 'テストオーナー' }
    let!(:room) { RoomRegistry.create_room(owner_name: owner_name).first }

    context '存在しないルームの場合' do
      it 'ルートパスにリダイレクトする' do
        get :show, params: { id: 'nonexistent' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('部屋が存在しません')
      end
    end

    context 'オーナーとしてアクセスする場合' do
      before do
        cookies.signed[:owner_token] = room.owner_token
      end

      it 'ルーム画面を表示する' do
        get :show, params: { id: room.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:owner_view)).to be true
        expect(assigns(:participants)).to be_present
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
    end

    context '未認証でアクセスする場合' do
      it '参加フォームを表示する' do
        get :show, params: { id: room.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:join_form)
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
      cookies.signed[:owner_token] = room.owner_token
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
        cookies.signed[:owner_token] = 'invalid_token'
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
      expect(json['selection']).to be_present
      expect(json['selection']['count']).to eq(1)
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
      it 'オーナートークンが一致する場合trueを返す' do
        cookies.signed[:owner_token] = room.owner_token
        get :show, params: { id: room.id }
        expect(assigns(:owner_view)).to be true
      end

      it 'オーナートークンが一致しない場合falseを返す' do
        cookies.signed[:owner_token] = 'invalid_token'
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
