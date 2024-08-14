# frozen_string_literal: true

require_relative '../mixin/sidekiq'


module BackgroundJob
  module Jobs
    class Sidekiq < Job
      OPTIONS_TO_PAYLOAD = %i[queue retry].freeze

      def initialize(job_class, **options)
        super(job_class, **Mixin::Sidekiq.background_job_options(job_class), **options)
        @options.slice(*OPTIONS_TO_PAYLOAD).each do |key, value|
          @payload[key.to_s] = value
        end
        @payload['class'] = job_class.to_s
        @payload['created_at'] ||= Time.now.to_f
      end

      # Push sidekiq to the Sidekiq(Redis actually).
      #   * If job has the 'at' key. Then schedule it
      #   * Otherwise enqueue for immediate execution
      #
      # @return [Hash] Payload that was sent to redis
      def push
        with_job_jid # Generate a unique job id
        payload['enqueued_at'] = Time.now.to_f
        BackgroundJob.config.sidekiq.middleware.invoke(self, :sidekiq) do
          # Optimization to enqueue something now that is scheduled to go out now or in the past
          if (timestamp = payload.delete('at')) && (timestamp > Time.now.to_f)
            redis_pool.with do |redis|
              redis.zadd(scheduled_queue_name, timestamp.to_f.to_s, to_json(payload))
            end
          else
            redis_pool.with do |redis|
              redis.lpush(immediate_queue_name, to_json(payload))
            end
          end
          payload
        end
      end

      protected

      def redis_pool
        BackgroundJob.config.sidekiq.redis_pool
      end

      def namespace
        BackgroundJob.config.sidekiq.namespace
      end

      def scheduled_queue_name
        [namespace, 'schedule'].compact.join(':')
      end

      def immediate_queue_name
        [namespace, 'queue', payload.fetch('queue')].compact.join(':')
      end

      def to_json(value)
        MultiJson.dump(value, mode: :compat)
      end
    end
  end
end
