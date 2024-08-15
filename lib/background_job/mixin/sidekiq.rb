# frizen_string_literal: true

require_relative './shared_interface'

module BackgroundJob
  module Mixin
    module Sidekiq
      DEFAULT = {
        queue: "default",
        retry: true
      }.freeze

      def self.background_job_options(job_class_name, strict_check: false)
        BackgroundJob.config.sidekiq.validate_strict_job!(job_class_name) if strict_check
        options = {}
        BackgroundJob.config.sidekiq.jobs[job_class_name]&.each do |key, value|
          options[key] = value
        end
        if defined?(::Sidekiq) && ::Sidekiq.respond_to?(:default_job_options)
          ::Sidekiq.default_job_options.each do |key, value|
            options[key.to_sym] ||= value
          end
        end
        if defined?(::Sidekiq) && ::Sidekiq.respond_to?(:default_worker_options)
          ::Sidekiq.default_worker_options.each do |key, value|
            options[key.to_sym] ||= value
          end
        end
        DEFAULT.each do |key, value|
          options[key] ||= value
        end
        options
      end

      class Builder < Module
        def initialize(native: false, **options)
          @native = native
          @runtime_mod = Module.new do
            define_method(:background_job_user_options) { options }
          end
        end

        def extended(base)
          if defined?(::Sidekiq::Job)
            base.include(::Sidekiq::Job)
          elsif defined?(::Sidekiq::Worker)
            base.include(::Sidekiq::Worker)
          end
          base.extend(BackgroundJob::Mixin::SharedInterface) unless @native
          base.extend ClassMethods
          base.extend @runtime_mod
        end

        module ClassMethods
          def background_job_service
            :sidekiq
          end

          def background_job_default_options
            BackgroundJob::Mixin::Sidekiq.background_job_options(name)
          end
        end
      end
    end
  end
end
