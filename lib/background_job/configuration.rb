# frozen_string_literal: true

require 'set'

module BackgroundJob
  class ConfigService < Set
    def sidekiq?
      include?(:sidekiq)
    end

    def faktory?
      include?(:faktory)
    end
  end

  class Configuration
    attr_reader :redis

    def reset!
      @redis = nil
      @redis_pool = nil
      @services = nil
      @faktory = nil
      @sidekiq = nil
    end

    def redis=(value)
      @redis_pool = nil
      @redis = value
    end

    def redis_pool
      @redis_pool ||= BackgroundJob::RedisPool.new(redis)
    end

    def services
      @services ||= ConfigService.new
    end

    def faktory
      @faktory ||= begin
        services.add(:faktory)
        require_relative 'jobs/faktory'
        Configuration::Faktory.new
      end
      if block_given?
        yield @faktory
      else
        @faktory
      end
    end

    def sidekiq
      @sidekiq ||= begin
        services.add(:sidekiq)
        require_relative 'jobs/sidekiq'
        Configuration::Sidekiq.new
      end
      if block_given?
        yield @sidekiq
      else
        @sidekiq
      end
    end
  end
end

require_relative 'configuration/base'
require_relative 'configuration/faktory'
require_relative 'configuration/sidekiq'
require_relative 'configuration/middleware_chain'
