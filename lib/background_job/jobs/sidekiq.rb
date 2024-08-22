# frozen_string_literal: true

require_relative '../mixin/sidekiq'


module BackgroundJob
  module Jobs
    class Sidekiq < Job
      OPTIONS_TO_PAYLOAD = %i[queue retry].freeze

      def initialize(job_class, **options)
        super(
          job_class,
          **Mixin::Sidekiq.background_job_options(job_class, strict_check: true),
          **options,
        )
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
      def push(**kwargs)
        normalize_before_push!

        kwargs[:retry] ||= 3 # retry is a reserved keyword
        BackgroundJob.config.sidekiq.middleware.invoke(self, :sidekiq) do
          retriable_connection(max_attempts: kwargs[:retry]) do |conn|
            # Optimization to enqueue something now that is scheduled to go out now or in the past
            if (timestamp = payload.delete('at')) && (timestamp > Time.now.to_f)
              conn.zadd(scheduled_queue_name, timestamp.to_f.to_s, to_json(payload))
            else
              payload['enqueued_at'] = Time.now.to_f
              conn.pipelined do |pipeline|
                pipeline.sadd(queues_set_name, [queue_name])
                pipeline.lpush(immediate_queue_name, to_json(payload))
              end
            end
          end
          payload
        end
      end

      protected

      def normalize_before_push!
        with_job_jid # Generate a unique job id
      end

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
        [namespace, 'queue', queue_name].compact.join(':')
      end

      def queues_set_name
        [namespace, 'queues'].compact.join(':')
      end

      def queue_name
        payload.fetch('queue')
      end

      def to_json(value)
        MultiJson.dump(value, mode: :compat)
      end

      def retriable_connection(max_attempts: 3)
        tries = 0
        redis_pool.with do |conn|
          yield conn
        rescue Redis::CommandError => ex
          if ex.message =~ /READONLY|NOREPLICAS|UNBLOCKED/ && tries < max_attempts
            tries += 1
            conn.close
            retry
          end
          raise ex
        end
      end
    end
  end
end
