# Redis connection test for Render.com
# Add this to config/initializers/ to test Redis connection

if Rails.env.production?
  begin
    redis_url = ENV['REDIS_URL']
    if redis_url.present?
      redis = Redis.new(url: redis_url)
      redis.ping
      Rails.logger.info "✅ Redis connection successful: #{redis_url}"
    else
      Rails.logger.warn "⚠️  REDIS_URL not found, using async adapter"
    end
  rescue => e
    Rails.logger.error "❌ Redis connection failed: #{e.message}"
    Rails.logger.error "Falling back to async adapter"
  end
end
