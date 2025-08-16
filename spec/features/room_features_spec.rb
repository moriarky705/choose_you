require 'rails_helper'

RSpec.describe 'ルーム機能', type: :feature do
  before do
    # テスト前にレジストリをクリア
    RoomRegistry.instance.instance_variable_set(:@rooms, {})
  end

  describe 'ルーム作成' do
    it 'オーナーがルームを作成できる' do
      visit root_path
      
      fill_in 'owner_name', with: 'テストオーナー'
      click_button '部屋を作る'
      
      expect(page).to have_content('ルーム')
      expect(page).to have_content('テストオーナー')
      expect(page).to have_content('オーナー')
      expect(page).to have_content('参加リンク')
    end

    it '無効なオーナー名でエラーが発生する' do
      visit root_path
      
      fill_in 'owner_name', with: ''
      click_button '部屋を作る'
      
      expect(page.status_code).to eq(400)
    end
  end

  describe '参加者の追加' do
    let!(:room_result) { RoomRegistry.create_room(owner_name: 'テストオーナー') }
    let!(:room) { room_result[0] }
    let!(:owner_token) { room_result[1] }

    it 'ゲストがルームに参加できる' do
      visit room_path(room.id)
      
      fill_in 'name', with: 'ゲスト1'
      click_button 'ルームに参加'
      
      expect(page).to have_content('ゲスト1')
      expect(page).to have_content('参加者')
    end

    it '複数のゲストが参加できる' do
      # 最初のゲスト
      visit room_path(room.id)
      fill_in 'name', with: 'ゲスト1'
      click_button 'ルームに参加'

      # 新しいセッションで2番目のゲスト（クッキークリア）
      Capybara.reset_sessions!
      visit room_path(room.id)
      fill_in 'name', with: 'ゲスト2'
      click_button 'ルームに参加'
      
      expect(page).to have_content('ゲスト2')
    end
  end

  describe 'オーナー権限' do
    let!(:room_result) { RoomRegistry.create_room(owner_name: 'テストオーナー') }
    let!(:room) { room_result[0] }
    let!(:owner_token) { room_result[1] }

    before do
      set_cookie('owner_token', owner_token)
    end

    it 'オーナーは抽選設定が表示される' do
      visit room_path(room.id)
      
      expect(page).to have_content('抽選設定')
      expect(page).to have_field('抽選人数')
      expect(page).to have_button('抽選開始')
    end

    it 'オーナーは抽選を実行できる' do
      # 参加者を追加
      RoomRegistry.add_participant(room_id: room.id, name: 'ゲスト1')
      RoomRegistry.add_participant(room_id: room.id, name: 'ゲスト2')
      
      visit room_path(room.id)
      
      fill_in '抽選人数', with: '2'
      click_button '抽選開始'
      
      expect(page).to have_content('抽選結果')
    end
  end

  describe 'ゲスト権限' do
    let!(:room_result) { RoomRegistry.create_room(owner_name: 'テストオーナー') }
    let!(:room) { room_result[0] }
    let!(:participant) { RoomRegistry.add_participant(room_id: room.id, name: '参加者') }

    before do
      set_cookie("participant_token_#{room.id}", participant.token)
    end

    it 'ゲストは抽選設定が表示されない' do
      visit room_path(room.id)
      
      expect(page).not_to have_content('抽選設定')
      expect(page).not_to have_field('抽選人数')
    end

    it 'ゲストは参加者リストを見ることができる' do
      visit room_path(room.id)
      
      expect(page).to have_content('参加者')
      expect(page).to have_content('参加者リスト')
    end
  end

  describe 'エラーハンドリング' do
    let!(:room_result) { RoomRegistry.create_room(owner_name: 'テストオーナー') }
    let!(:room) { room_result[0] }

    it 'オーナー権限なしで抽選を実行するとエラーになる' do
      # オーナー権限なしでPOST
      page.driver.post(select_room_path(room.id), { count: 1 })
      expect(page.status_code).to eq(403)
    end

    it '存在しないルームにアクセスするとリダイレクトされる' do
      visit room_path('nonexistent')
      expect(page).to have_current_path(root_path)
    end
  end

  describe 'UI要素' do
    it 'ルートページに必要な要素が表示される' do
      visit root_path
      
      expect(page).to have_content('部屋を作成')
      expect(page).to have_field('owner_name')
      expect(page).to have_button('部屋を作る')
    end

    it 'ルーム画面に必要な要素が表示される' do
      visit root_path
      fill_in 'owner_name', with: 'テストオーナー'
      click_button '部屋を作る'
      
      expect(page).to have_content('ルーム')
      expect(page).to have_content('参加リンク')
      expect(page).to have_button('コピー')
    end
  end
end
