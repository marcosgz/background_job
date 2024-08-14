# frizen_string_literal: true

require_relative './shared_interface'

module BackgroundJob
  module Mixin
    module Faktory
      DEFAULT = {
        queue: "default",
        retry: 25
      }.freeze

      def self.background_job_options(job_class_name)
        options = {}
        BackgroundJob.config.faktory.jobs[job_class_name]&.each do |key, value|
          options[key] = value
        end
        if defined?(::Faktory)
          ::Faktory.default_job_options.each do |key, value|
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
          base.include(::Faktory::Job) if defined?(::Faktory)
          base.extend BackgroundJob::Mixin::SharedInterface
          base.extend ClassMethods
          base.extend @runtime_mod
        end

        module ClassMethods
          def background_job_service
            :faktory
          end

          def background_job_default_options
            BackgroundJob::Mixin::Faktory.background_job_options(name)
          end
        end
      end
    end
  end
end
