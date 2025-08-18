# frozen_string_literal: true

# アプリケーション起動時とRender.comのスリープ復帰時の初期化処理
Rails.application.config.after_initialize do
  if Rails.env.production?
    # 期限切れ部屋のクリーンアップ
    Rails.logger.info "Starting room cleanup on application boot..."
    cleaned_count = RoomRegistry.cleanup_expired_rooms
    Rails.logger.info "Cleaned up #{cleaned_count} expired rooms on boot"
    
    # 定期的なクリーンアップ（6時間毎）
    Thread.new do
      loop do
        sleep 6.hours
        begin
          cleaned_count = RoomRegistry.cleanup_expired_rooms
          Rails.logger.info "Periodic cleanup: removed #{cleaned_count} expired rooms"
        rescue => e
          Rails.logger.error "Error in periodic room cleanup: #{e.message}"
        end
      end
    end
  end
end
