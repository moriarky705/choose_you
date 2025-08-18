# frozen_string_literal: true

# セッション設定の最適化
Rails.application.configure do
  # Render.com本番環境でのセッション設定
  if Rails.env.production?
    # セッションCookieの設定を最適化
    config.session_store :cookie_store,
      key: '_choose_you_session',
      secure: true,                    # HTTPS必須
      httponly: true,                  # XSS対策
      same_site: :lax,                 # CSRF対策とSPA対応のバランス
      expire_after: 24.hours           # 24時間でセッション期限切れ
  else
    # 開発環境では緩い設定
    config.session_store :cookie_store,
      key: '_choose_you_session_dev',
      secure: false,                   # HTTP許可
      httponly: true,
      same_site: :lax,
      expire_after: 24.hours
  end
end
