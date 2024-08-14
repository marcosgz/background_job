# frozen_string_literal: true

require_relative '../mixin/faktory'

module BackgroundJob
  module Jobs
    class Faktory < Job
      def initialize(job_class, **options)
        super(
          job_class,
          **Mixin::Faktory.background_job_options(job_class, strict_check: true),
          **options
        )
        @options.slice(:queue, :reserve_for).each do |key, value|
          @payload[key.to_s] = value
        end
        @payload['jobtype'] = job_class.to_s
        @payload['retry'] = parse_retry(@options[:retry])
        @payload['created_at'] ||= Time.now.to_f
      end

      # Push job to Faktory
      #   * If job has the 'at' key. Then schedule it
      #   * Otherwise enqueue for immediate execution
      #
      # @raise [BackgroundJob::Error] raise and error when faktory dependency is not loaded
      # @return [Hash] Payload that was sent to server
      def push
        unless Object.const_defined?(:Faktory)
          raise BackgroundJob::Error, <<~ERR
          Faktory client for ruby is not loaded. You must install and require https://github.com/contribsys/faktory_job_ruby.
          ERR
        end
        normalize_before_push!
        pool = Thread.current[:faktory_via_pool] || ::Faktory.server_pool
        BackgroundJob.config.faktory.middleware.invoke(self, :faktory) do
          ::Faktory.client_middleware.invoke(payload, pool) do
            pool.with do |c|
              c.push(payload)
            end
          end
          payload
        end
      end

      protected

      def normalize_before_push!
        with_job_jid # Generate a unique job id
        payload['enqueued_at'] = Time.now.to_f
        {'created_at' => false, 'enqueued_at' => false, 'at' => true}.each do |field, past_remove|
          # Optimization to enqueue something now that is scheduled to go out now or in the past
          if (time = payload.delete(field)) &&
              (!past_remove || (past_remove && time > Time.now.to_f))
            payload[field] = parse_time(time)
          end
        end
      end

      # Convert job retry value acording to the Go struct datatype.
      #
      # * 25 is the default.
      # * 0 means the job is completely ephemeral. No matter if it fails or succeeds, it will be discarded.
      # * -1 means the job will go straight to the Dead set if it fails, no retries.
      def parse_retry(value)
        case value
        when Numeric then value.to_i
        when false then -1
        else
          25
        end
      end

      def parse_time(value)
        case value
        when Numeric then Time.at(value).to_datetime.rfc3339(9)
        when Time then value.to_datetime.rfc3339(9)
        when DateTime then value.rfc3339(9)
        end
      end

      def to_json(value)
        MultiJson.dump(value, mode: :compat)
      end
    end
  end
end
