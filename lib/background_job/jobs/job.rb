# frozen_string_literal: true

require_relative '../unique_job'

# DSL used to create a job. It's generic so it can be used with any adapter.
module BackgroundJob
  class Jobs::Job
    attr_reader :options, :payload, :job_class, :unique_job

    def initialize(job_class, **options)
      @job_class = job_class
      @options = options
      @payload = {}
      unique(@options.delete(:uniq)) if @options.key?(:uniq)
    end

    # Push the job to the service backend
    #
    # @abstract
    def push
      raise NotImplementedError
    end

    %i[created_at enqueued_at].each do |method_name|
      define_method method_name do |value|
        payload[method_name.to_s] = \
          case value
          when Numeric then value.to_f
          when String then Time.parse(value).to_f
          when Time, DateTime then value.to_f
          else
            raise ArgumentError, format('The %<v>p is not a valid value for %<m>s.', v: value, m: method_name)
          end

        self
      end
    end

    # Adds arguments to the job
    # @return self
    def with_args(*args)
      payload['args'] = args

      self
    end

    # Schedule the time when a job will be executed. Jobs which are scheduled in the past are enqueued for immediate execution.
    # @param timestamp [Numeric] timestamp, numeric or something that acts numeric.
    # @return self
    def in(timestamp)
      now = Time.now.to_f
      timestamp = Time.parse(timestamp) if timestamp.is_a?(String)
      int = timestamp.respond_to?(:strftime) ? timestamp.to_f : now + timestamp.to_f
      return self if int <= now

      payload['at'] = int
      payload['created_at'] = now

      self
    end
    alias_method :at, :in

    # Wrap uniq options
    #
    # @param value [Hash] Unique configurations with `across`, `timeout` and `unlock_policy`
    # @return self
    def unique(value)
      value = {} if value == true
      @unique_job = \
        case value
        when Hash then UniqueJob.coerce(value)
        when UniqueJob then value
        else
          nil
        end

      self
    end

    def with_job_jid(jid = nil)
      payload['jid'] ||= jid || BackgroundJob.jid

      self
    end

    def eql?(other)
      return false unless other.is_a?(self.class)

      job_class == other.job_class && \
        payload == other.payload &&
        options == other.options &&
        unique_job == other.unique_job
    end
    alias == eql?

    def unique_job?
      unique_job.is_a?(UniqueJob)
    end

    def to_s
      # format(
      #   '#<%<c>s:0x%<o>x job_class=%<j>p, payload=%<p>p, options=%<o>p, unique_job=%<u>p>',
      #   c: self.class, o: object_id, j: job_class, p: payload, o: options, u: unique_job
      # )
      str = format(
        '#<%<c>s:0x%<o>x job_class=%<j>p',
        c: self.class, o: object_id, j: job_class
      )
      if (args = payload['args'])
        str += format(', args=%<p>p', p: args)
      end
      str += format(', options=%<o>p', o: options) unless options.empty?
      str += format(', unique_job=%<u>p', u: unique_job) if unique_job
      str += '>'
      str
    end

    private

    # Normalize payload before pushing to the service
    # @abstract
    def normalize_before_push!
      # noop
    end
  end
end
