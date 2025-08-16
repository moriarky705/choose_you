# 🎯 Choose You - リアルタイム抽選アプリ

[![Ruby](https://img.shields.io/badge/Ruby-3.2.9-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.0.2-red.svg)](https://rubyonrails.org/)
[![JavaScript](https://img.shields.io/badge/JavaScript-ES6+-yellow.svg)](https://developer.mozilla.org/en-US/docs/Web/JavaScript)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg)](https://www.docker.com/)
[![Tests](https://img.shields.io/badge/Tests-47%20passing-green.svg)](./TESTING.md)

リアルタイムで複数人が参加できる抽選システム。オンライン会議、イベント、チーム活動での抽選に最適です。

## ✨ 主な機能

### 🏠 ルーム管理
- **ルーム作成**: オーナーが抽選ルームを簡単に作成
- **招待リンク**: ワンクリックで参加者を招待
- **リアルタイム参加者表示**: 参加者リストがリアルタイムで更新

### 🎲 抽選機能
- **カスタム抽選数**: 1人から全員まで自由に設定
- **リアルタイム結果配信**: 全参加者に同時に結果を表示
- **公平な抽選**: 真の乱数による公正な抽選

### 🌐 リアルタイム通信
- **ActionCable**: WebSocketによる高速リアルタイム通信
- **フォールバック機能**: 接続問題時は自動でポーリングに切替
- **クロスブラウザ対応**: すべての主要ブラウザで動作

### 📱 レスポンシブデザイン
- **モバイル対応**: スマートフォンでも快適に利用
- **Material Design**: 直感的で美しいUI
- **Tailwind CSS**: 高速で一貫したスタイリング

## 🚀 クイックスタート

### 前提条件
- Docker & Docker Compose
- Git

### セットアップ
```bash
# リポジトリをクローン
git clone https://github.com/moriarky705/choose_you.git
cd choose_you/app

# Docker環境でアプリケーションを起動
docker compose up -d

# 依存関係のインストール
docker compose exec app bundle install
docker compose exec app npm install

# アセットをビルド
docker compose exec app npm run build

# アプリケーションにアクセス
open http://localhost:3000
```

### 本番環境デプロイ (Render.com)
```bash
# 本番用アセットビルド
npm run build:production

# 環境変数設定
RAILS_ENV=production
REDIS_URL=redis://your-redis-url
SECRET_KEY_BASE=your-secret-key
```

## 🛠️ 技術スタック

### バックエンド
- **Ruby 3.2.9**: 最新の安定版Ruby
- **Rails 8.0.2**: 最新のRailsフレームワーク
- **ActionCable**: WebSocketリアルタイム通信
- **Redis**: ActionCableアダプター（本番環境）
- **RoomRegistry**: インメモリルーム管理（データベース不使用）

### フロントエンド
- **Stimulus.js**: Railsネイティブなフロントエンドフレームワーク
- **Turbo**: SPAライクなページ遷移
- **esbuild**: 高速JavaScriptバンドラー
- **Tailwind CSS**: ユーティリティファーストCSS

### インフラ・デプロイ
- **Docker**: 開発環境の統一
- **Render.com**: 無料プランでの本番デプロイ
- **GitHub Actions**: CI/CD（設定可能）

### テスト
- **RSpec**: BDD形式のテストフレームワーク
- **Capybara**: 統合テスト
- **FactoryBot**: テストデータ生成
- **100%テストカバレッジ**: 47例すべて通過

## 📋 使い方

### 1. ルーム作成
1. トップページでオーナー名を入力
2. 「部屋を作る」をクリック
3. 招待リンクが生成される

### 2. 参加者招待
1. 招待リンクをコピー
2. 参加者にリンクを共有
3. 参加者は名前を入力して参加

### 3. 抽選実行
1. オーナーが抽選人数を設定
2. 「抽選開始」をクリック
3. 結果が全員にリアルタイム配信

### 4. リアルタイム更新
- 参加者の追加/削除が即座に反映
- 抽選結果が同時に全員に表示
- 接続状況に応じて自動でフォールバック

## 🏗️ アーキテクチャ

### システム構成
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Browser       │    │   Rails App     │    │   Redis         │
│   (Stimulus)    │◄──►│   (ActionCable) │◄──►│   (Production)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         │                       ▼
         │              ┌─────────────────┐
         └─────────────►│   RoomRegistry  │
          (Polling)     │   (In-Memory)   │
                        └─────────────────┘
```

### サービス層設計
- **RoomAuthorizationService**: 認証・認可の管理
- **ActionCableBroadcastService**: リアルタイム通信の統一
- **RoomRegistry**: ルーム・参加者の状態管理

### フロントエンド設計
- **RoomController**: メインコントローラー
- **ConnectionConfig**: 接続設定管理
- **MessageHandler**: メッセージ処理
- **Renderers**: UI描画の分離
- **CopyHandler**: クリップボード機能

## 🧪 テスト

### テスト実行
```bash
# 全テスト実行
docker compose exec app bundle exec rspec

# 特定ファイルのテスト
docker compose exec app bundle exec rspec spec/models/room_registry_spec.rb

# カバレッジ詳細表示
docker compose exec app bundle exec rspec --format documentation
```

### テスト構成
- **Unit Tests**: RoomRegistry, サービスクラス
- **Controller Tests**: RoomsController, ActionCable
- **Integration Tests**: エンドツーエンドシナリオ
- **47例 100%通過**: 完全なテストカバレッジ

詳細は [TESTING.md](./TESTING.md) を参照してください。

## 🔧 開発

### 開発環境セットアップ
```bash
# 開発用サーバー起動
docker compose exec app bin/dev

# ログ確認
docker compose logs -f app

# コンテナ内でのデバッグ
docker compose exec app bash
```

### コード品質
- **SOLID原則**: 適切な責任分離
- **DRY原則**: コード重複の排除
- **Rails規約**: Railsのベストプラクティスに準拠
- **セキュリティ**: XSS対策、CSRF保護

### JavaScript開発
```bash
# 開発用ビルド（ソースマップ付き）
npm run build

# ウォッチモード
npm run build:watch

# 本番用ビルド（最適化）
npm run build:production
```

## 📊 パフォーマンス

### リアルタイム通信
- **WebSocket優先**: 低遅延でのリアルタイム通信
- **ポーリングフォールバック**: 接続問題時の自動切替
- **Redis対応**: 本番環境でのスケーラブルな通信

### メモリ効率
- **データベース不使用**: 軽量なインメモリ構成
- **自動クリーンアップ**: 不要なデータの定期削除
- **効率的な状態管理**: 最小限のメモリ使用

## 🌍 本番環境

### Render.com デプロイ
本アプリケーションはRender.comの無料プランで動作します：

- **Web Service**: Railsアプリケーション
- **Redis Service**: ActionCable用データストア
- **Static Assets**: esbuildで最適化

### 環境設定
```yaml
# render.yaml
services:
  - type: web
    name: choose-you
    runtime: ruby
    buildCommand: bundle install && npm ci && npm run build:production
    startCommand: bundle exec rails server -b 0.0.0.0 -p $PORT
    env: ruby-3.2.9
    plan: free
```

### 本番環境の特徴
- **SSL対応**: HTTPS強制
- **CDN**: 静的アセットの高速配信
- **ヘルスチェック**: `/up` エンドポイント
- **ログ管理**: 構造化ログ出力

## 🤝 コントリビューション

### 開発への参加
1. Forkしてブランチを作成
2. 変更を実装
3. テストを追加・実行
4. Pull Requestを作成

### コードスタイル
- **RuboCop**: Ruby標準スタイル
- **Prettier**: JavaScript整形
- **Rails規約**: MVC分離、RESTful API

### Issue報告
- バグ報告
- 機能要求
- パフォーマンス改善提案

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。

## 🙏 謝辞

- **Rails Team**: 素晴らしいフレームワーク
- **Stimulus Team**: 直感的なJavaScriptフレームワーク
- **Tailwind CSS**: 美しいデザインシステム
- **Render.com**: 簡単で強力なデプロイプラットフォーム

---

📧 質問やサポートが必要な場合は、[Issues](https://github.com/moriarky705/choose_you/issues) からお気軽にお問い合わせください。
