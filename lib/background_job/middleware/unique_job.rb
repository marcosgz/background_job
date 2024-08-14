# frozen_string_literal: true

require 'background_job/lock'
require 'background_job/lock_digest'

module BackgroundJob
  module Middleware
    # This middleware uses an external redis queue to control duplications. The locking key
    # is composed of job class and its arguments. Before enqueue new jobs it will check if have a "lock" active.
    # The TTL of lock is 1 week as default. TTL is important to ensure locks won't last forever.
    class UniqueJob
      def self.bootstrap(service:)
        services = Dir[File.expand_path('../unique_job/*.rb', __FILE__)].map { |f| File.basename(f, '.rb').to_sym }
        unless services.include?(service)
          msg = "UniqueJob is not supported for the `%<service>p' service. Supported options are: %<services>s."
          raise BackgroundJob::Error, format(msg, service: service.to_sym, services: services.map { |s| "`:#{s}'" }.join(', '))
        end
        if (require("background_job/middleware/unique_job/#{service}"))
          class_name = service.to_s.split('_').collect!{ |w| w.capitalize }.join
          BackgroundJob::Middleware::UniqueJob.const_get(class_name).bootstrap
        end

        service_config = BackgroundJob.config_for(service)
        service_config.unique_job_active = true
        service_config.middleware.add(UniqueJob)
      end

      def call(job, service)
        if BackgroundJob.config_for(service).unique_job_active? &&
            (uniq_lock = unique_job_lock(job: job, service: service))
          return false if uniq_lock.locked? # Don't push job to server

          # Add unique job information to the job payload
          job.unique_job.lock = uniq_lock
          job.payload['uniq'] = job.unique_job.to_hash

          uniq_lock.lock
        end

        yield
      end

      protected

      def unique_job_lock(job:, service:)
        return unless job.unique_job?

        digest = LockDigest.new(
          *[service || job.options[:service], job.options[:queue]].compact,
          across: job.unique_job.across,
        )
        Lock.new(
          digest: digest.to_s,
          lock_id: unique_job_lock_id(job),
          ttl: job.unique_job.ttl,
        )
      end

      def unique_job_lock_id(job)
        identifier_data = [job.job_class, job.payload.fetch('args'.freeze, [])]
        Digest::SHA256.hexdigest(
          MultiJson.dump(identifier_data, mode: :compat),
        )
      end
    end
  end
end
