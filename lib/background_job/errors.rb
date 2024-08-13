# frozen_string_literal: true

module BackgroundJob
  class Error < StandardError
  end

  class InvalidConfigError < Error
  end

  class NotDefinedJobError < Error
    def initialize(job_class)
      @job_class = job_class
    end

    def message
      format(
        "The %<worker>p is not defined and the BackgroundJob is configured to work on strict mode.\n" +
        "it's highly recommended to include this worker class to the list of known workers.\n" +
        "Example: `BackgroundJob.configure { |config| config.sidekiq.workers = { %<worker>p => {} } }`\n" +
        'Another option is to set config.strict = false',
        worker: @job_class,
      )
    end
  end
end
