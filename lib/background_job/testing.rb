# frozen_string_literal: true

module BackgroundJob
  class Testing
    class << self
      def enable!
        Thread.current[:background_job_testing] = true
      end

      def disable!
        Thread.current[:background_job_testing] = false
      end

      def enabled?
        Thread.current[:background_job_testing] == true
      end

      def disabled?
        !enabled?
      end
    end
  end
end

BackgroundJob::Testing.disable!

module BackgroundJob::Jobs
  class << self
    def jobs
      @jobs ||= []
    end

    def push(job)
      jobs.push(job)
    end

    def clear
      jobs.clear
    end

    def size
      jobs.size
    end

    def jobs_for(service: nil, class_name: nil)
      filtered = jobs
      if service
        filtered = filtered.select do |job|
          job.class.name.split("::").last.downcase == service.to_s
        end
      end
      if class_name
        filtered = filtered.select do |job|
          job.job_class == class_name
        end
      end
      filtered
    end
  end
end

module BackgroundJob::JobsInterceptorAdapter
  def push
    return super unless BackgroundJob::Testing.enabled?

    normalize_before_push!
    BackgroundJob::Jobs.push(self)
  end
end

BackgroundJob::SERVICES.each do |service_name, class_name|
  require_relative "./jobs/#{service_name}"

  klass = Object.const_get("BackgroundJob::Jobs::#{class_name}")
  klass.prepend(BackgroundJob::JobsInterceptorAdapter)
end
