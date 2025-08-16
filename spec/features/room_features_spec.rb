require 'rails_helper'

RSpec.describe 'ルーム機能', type: :feature do
  before do
    # テスト前にレジストリをクリア
    RoomRegistry.instance.instance_variable_set(:@rooms, {})
  end

  describe 'ルーム作成' do
    it 'オーナーがルームを作成できる' do
      visit root_path
      
      fill_in 'オーナー名', with: 'テストオーナー'
      click_button 'ルーム作成'
      
      expect(page).to have_content('ルーム')
      expect(page).to have_content('テストオーナー')
      expect(page).to have_content('オーナー')
      expect(page).to have_content('参加リンク')
    end

    it '無効なオーナー名でエラーが発生する' do
      visit root_path
      
      fill_in 'オーナー名', with: ''
      expect {
        click_button 'ルーム作成'
      }.to raise_error(ActionController::ParameterMissing)
    end
  end

  describe '参加者の追加' do
    let!(:room) { RoomRegistry.create_room(owner_name: 'テストオーナー').first }

    it 'ゲストがルームに参加できる' do
      visit room_path(room.id)
      
      expect(page).to have_content('ルームに参加')
      
      fill_in '名前', with: 'ゲスト1'
      click_button 'ルームに参加'
      
      expect(page).to have_content('ゲスト')
      expect(page).to have_content('ゲスト1')
      expect(page).to have_content('抽選設定')
    end

    it '複数のゲストが参加できる' do
      # 最初のゲストが参加
      visit room_path(room.id)
      fill_in '名前', with: 'ゲスト1'
      click_button 'ルームに参加'
      
      # 新しいセッションで2番目のゲスト（クッキーをクリア）
      page.driver.browser.manage.delete_all_cookies
      visit room_path(room.id)
      fill_in '名前', with: 'ゲスト2'
      click_button 'ルームに参加'
      
      # 参加者数の確認は実際のブラウザではActionCableで更新されるが、
      # テストでは手動でページを確認
      visit room_path(room.id)
      expect(page).to have_content('ゲスト2')
    end
  end

  describe 'オーナー権限' do
    let!(:room_and_token) { RoomRegistry.create_room(owner_name: 'テストオーナー') }
    let!(:room) { room_and_token.first }
    let!(:owner_token) { room_and_token.last }

    before do
      # オーナートークンをクッキーに設定
      page.driver.browser.manage.add_cookie(
        name: 'owner_token',
        value: owner_token
      )
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
      expect(page).to have_css('.bg-orange-100', count: 2) # 当選者の表示
    end
  end

  describe 'ゲスト権限' do
    let!(:room) { RoomRegistry.create_room(owner_name: 'テストオーナー').first }
    let!(:participant) { RoomRegistry.add_participant(room_id: room.id, name: 'ゲスト1') }

    before do
      # 参加者トークンをクッキーに設定
      page.driver.browser.manage.add_cookie(
        name: "participant_token_#{room.id}",
        value: participant.token
      )
    end

    it 'ゲストは抽選設定が表示されない' do
      visit room_path(room.id)
      
      expect(page).to have_content('ゲスト')
      expect(page).not_to have_content('抽選設定')
      expect(page).not_to have_button('抽選開始')
    end

    it 'ゲストは参加者リストを見ることができる' do
      visit room_path(room.id)
      
      expect(page).to have_content('参加者')
      expect(page).to have_content('テストオーナー')
      expect(page).to have_content('ゲスト1')
    end
  end

  describe 'エラーハンドリング' do
    it '存在しないルームにアクセスするとリダイレクトされる' do
      visit room_path('nonexistent')
      
      expect(page).to have_current_path(root_path)
      expect(page).to have_content('部屋が存在しません')
    end

    it 'オーナー権限なしで抽選を実行するとリダイレクトされる' do
      room = RoomRegistry.create_room(owner_name: 'テストオーナー').first
      
      # オーナートークンなしでアクセス
      visit room_path(room.id)
      
      # 直接POSTリクエストを送信してみる（通常のUIではボタンが表示されない）
      page.driver.post(select_room_path(room.id), { count: 1 })
      
      expect(page).to have_current_path(root_path)
      expect(page).to have_content('権限がありません')
    end
  end

  describe 'UI要素' do
    let!(:room) { RoomRegistry.create_room(owner_name: 'テストオーナー').first }

    it 'ルートページに必要な要素が表示される' do
      visit root_path
      
      expect(page).to have_title('Room Selector')
      expect(page).to have_content('新しいルームを作成')
      expect(page).to have_field('オーナー名')
      expect(page).to have_button('ルーム作成')
    end

    it 'ルーム画面に必要な要素が表示される' do
      visit room_path(room.id)
      
      expect(page).to have_content('ルーム')
      expect(page).to have_content('参加者')
      expect(page).to have_content('参加リンク')
      expect(page).to have_button('コピー')
    end
  end
end
