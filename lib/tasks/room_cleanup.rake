# frozen_string_literal: true

# 期限切れの部屋を定期的にクリーンアップするタスク
namespace :rooms do
  desc "期限切れの部屋をクリーンアップする"
  task cleanup: :environment do
    puts "期限切れの部屋をクリーンアップ中..."
    
    cleaned_count = RoomRegistry.cleanup_expired_rooms
    
    if cleaned_count > 0
      puts "#{cleaned_count}個の期限切れ部屋を削除しました"
    else
      puts "削除対象の期限切れ部屋はありませんでした"
    end
    
    puts "現在の部屋数: #{RoomRegistry.instance.instance_variable_get(:@rooms).size}"
  end
end
