# frozen_string_literal: true

module BackgroundJob
  class Configuration::Sidekiq < Configuration::Base
    attribute_accessor :redis, write: false
    # It's recommended to not use the namespace option in Sidekiq.
    # @see http://www.mikeperham.com/2015/09/24/storing-data-with-redis/#namespaces
    attribute_accessor :namespace

    def redis_pool
      @redis_pool ||= if redis
        BackgroundJob::RedisPool.new(redis)
      else
        BackgroundJob.config.redis_pool
      end
    end

    def redis=(value)
      @redis_pool = nil
      @redis = value
    end
  end
end
