# frizen_string_literal: true

module BackgroundJob
  module Mixin
    module SharedInterface
      def perform_async(*args)
        build_job.with_args(*args).push
      end

      def perform_in(interval, *args)
        build_job.with_args(*args).at(interval).push
      end
      alias_method :perform_at, :perform_in

      # This method should be overridden in the including class
      # @return [Symbol]
      # @see BackgroundJob::Mixin::Sidekiq::ClassMethods
      # @see BackgroundJob::Mixin::Faktory::ClassMethods
      #
      # @abstract
      def background_job_service
        raise NotImplementedError
      end

      # This method should be overridden in the including class
      # @return [Hash]
      # @see BackgroundJob::Mixin::Sidekiq::ClassMethods
      # @see BackgroundJob::Mixin::Faktory::ClassMethods
      #
      # @abstract
      def background_job_default_options
        raise NotImplementedError
      end

      # This method will be defined as a singleton method when the including class is extended
      # @return [Hash] The hash of options to be passed to the background job
      # @see BackgroundJob.mixin to see how this method is defined
      def background_job_user_options
        raise NotImplementedError
      end

      protected

      def build_job
        BackgroundJob.send(background_job_service, name, **background_job_default_options, **background_job_user_options)
      end
    end
  end
end
