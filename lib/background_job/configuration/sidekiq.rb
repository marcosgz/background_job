# frozen_string_literal: true

module BackgroundJob
  class Configuration::Sidekiq < Configuration::Base
    attribute_accessor :redis
    attribute_accessor :namespace

    def redis_pool
      @redis_pool ||= BackgroundJob::RedisPool.new(redis)
    end
  end
end
