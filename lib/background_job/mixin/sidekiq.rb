# frizen_string_literal: true

require_relative './shared_interface'

module BackgroundJob
  module Mixin
    module Sidekiq
      DEFAULT = {
        queue: "default",
        retry: true
      }.freeze

      def self.background_job_options(job_class_name)
        options = {}
        BackgroundJob.config.sidekiq.workers.dig(job_class_name)&.each do |key, value|
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
        def initialize(**options)
          @runtime_mod = Module.new do
            define_method(:background_job_user_options) { options }
          end
        end

        def extended(base)
          base.include(::Sidekiq::Worker) if defined?(::Sidekiq)
          base.extend BackgroundJob::Mixin::SharedInterface
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
