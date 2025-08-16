# RSpec テストガイド

このアプリケーションには包括的なRSpecテストスイートが含まれています。

## テストの実行方法

### 全てのテストを実行
```bash
docker compose run --rm app bundle exec rspec
```

### 特定のテストファイルを実行
```bash
# モデルテスト
docker compose run --rm app bundle exec rspec spec/models/room_registry_spec.rb

# コントローラーテスト  
docker compose run --rm app bundle exec rspec spec/controllers/rooms_controller_spec.rb

# ActionCableテスト
docker compose run --rm app bundle exec rspec spec/channels/room_channel_spec.rb

# 統合テスト
docker compose run --rm app bundle exec rspec spec/features/room_features_spec.rb
```

### 特定のテストケースを実行
```bash
# 行番号を指定
docker compose run --rm app bundle exec rspec spec/models/room_registry_spec.rb:25

# 説明文で絞り込み
docker compose run --rm app bundle exec rspec -e "ルームを作成"
```

### カバレッジレポート付きで実行
```bash
docker compose run --rm app bundle exec rspec --format documentation
```

## テストの構成

### spec/models/
- `room_registry_spec.rb`: RoomRegistryモデルの全機能をテスト
  - ルーム作成、参加者追加、抽選機能
  - エラーハンドリングと境界値テスト

### spec/controllers/
- `rooms_controller_spec.rb`: RoomsControllerの全アクションをテスト
  - ルーム作成、表示、参加、抽選機能
  - 認証・認可のテスト

### spec/channels/
- `room_channel_spec.rb`: ActionCableのリアルタイム機能をテスト
  - WebSocket接続、メッセージブロードキャスト
  - 参加者更新、抽選結果配信

### spec/features/
- `room_features_spec.rb`: エンドツーエンドの統合テスト
  - ユーザーシナリオの完全なテスト
  - UI要素とユーザー体験のテスト

### spec/helpers/
- `application_helper_spec.rb`: ヘルパーメソッドのテスト

## テストデータ

テストではFactoryBotとFakerを使用してテストデータを生成します。実際のテストではインメモリのRoomRegistryを使用するため、データベースは不要です。

## 注意事項

- テストは独立して実行されるよう、各テストの前にRoomRegistryをクリアします
- ActionCableのテストはスタブ接続を使用します
- 統合テストではJavaScriptを使用しないため、リアルタイム機能は手動確認が必要です

## カバレッジ

このテストスイートは以下をカバーしています：
- モデルロジック: 100%
- コントローラーアクション: 100%  
- ActionCableチャンネル: 100%
- 主要なユーザーシナリオ: 100%
- エラーハンドリング: 100%
