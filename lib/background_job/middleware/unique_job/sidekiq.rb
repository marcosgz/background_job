# frozen_string_literal: true


# Provides the Sidekiq middleware that make the unique job control work
#
# @see https://github.com/contribsys/faktory_worker_ruby/wiki/Middleware
module BackgroundJob
  module Middleware
    class UniqueJob
      module Sidekiq
        def self.bootstrap
          if defined?(::Sidekiq)
            ::Sidekiq.configure_worker do |config|
              config.worker_middleware do |chain|
                chain.add Worker
              end
            end
          end
        end

        # Worker middleware runs around the execution of a job
        class Worker
          # @param jobinst [Object] the worker/job instance
          # @param payload [Hash] the full job payload
          #   * @see https://github.com/mperham/sidekiq/wiki/Job-Format
          # @param queue [String] the name of the queue the job was pulled from
          # @yield the next middleware in the chain or worker `perform` method
          # @return [Void]
          def call(_jobinst, payload, _queue)
            if payload.is_a?(Hash) && (unique_lock = unique_job_lock(payload))
              unique_lock.unlock
            end
            yield
          end

          protected

          def unique_job_lock(job)
            return unless job['uniq'].is_a?(Hash)

            unique_job = ::BackgroundJob::UniqueJob.coerce(job['uniq'])
            unique_job&.lock
          end
        end
      end
    end
  end
end
