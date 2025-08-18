# frozen_string_literal: true

# アプリケーション起動時とRender.comのスリープ復帰時の初期化処理
Rails.application.config.after_initialize do
  if Rails.env.production?
    begin
      # RoomRegistryクラスが利用可能になってからクリーンアップ実行
      Rails.application.executor.wrap do
        # 期限切れ部屋のクリーンアップ
        Rails.logger.info "Starting room cleanup on application boot..."
        cleaned_count = RoomRegistry.cleanup_expired_rooms
        Rails.logger.info "Cleaned up #{cleaned_count} expired rooms on boot"
      end
      
      # バックグラウンド処理は別途ActiveJobやRakeタスクで実行する方式に変更
      # Renderの無料プランではThreadが制限される可能性があるため無効化
      Rails.logger.info "Room cleanup initialization completed"
      
    rescue => e
      Rails.logger.error "Error during room cleanup initialization: #{e.message}"
      # 初期化エラーでもアプリケーション起動は続行
    end
  end
end
