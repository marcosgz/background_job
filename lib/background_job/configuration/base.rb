# frozen_string_literal: true

class BackgroundJob::Configuration::Base
  class << self
    private

    def attribute_accessor(field, validator: nil, normalizer: nil, default: nil, write: true, read: true)
      normalizer ||= :"normalize_#{field}"
      validator ||= :"validate_#{field}"

      define_method(field) do
        unless instance_variable_defined?(:"@#{field}")
          fallback = config_from_yaml[field.to_s] || default
          return if fallback.nil?

          send(:"#{field}=", fallback.respond_to?(:call) ? fallback.call : fallback)
        end
        instance_variable_get(:"@#{field}")
      end if read

      define_method(:"#{field}=") do |value|
        value = send(normalizer, field, value) if respond_to?(normalizer, true)
        send(validator, field, value) if respond_to?(validator, true)

        instance_variable_set(:"@#{field}", value)
      end if write
    end
  end

  # Path to the YAML file with configs
  attr_reader :config_path

  # A Hash with all jobs definitions. The job class name must be the main hash key
  # Example:
  #   "FaktoryIndexWorker":
  #     retry: false
  #     queue: "indexing"
  #     adapter: "faktory"
  #   "FaktoryBatchIndexWorker":
  #     retry: 5
  #     queue: "batch_index"
  #     adapter: "faktory"
  attribute_accessor :jobs, default: {}

  # Global disable the unique_job_active
  attribute_accessor :unique_job_active, default: false
  alias unique_job_active? unique_job_active

  # Does not validate if it's when set to false
  attribute_accessor :strict, default: true
  alias strict? strict

  def validate_strict_job!(class_name)
    class_name = class_name.to_s
    if strict? && !jobs.key?(class_name)
      raise BackgroundJob::NotDefinedJobError.new(class_name)
    end
    true
  end

  def config_path=(value)
    @config_from_yaml = nil
    @config_path = value
  end

  def middleware
    @middleware ||= BackgroundJob::Configuration::MiddlewareChain.new
    yield @middleware if block_given?
    @middleware
  end

  protected

  def normalize_jobs(_, value)
    return unless value.is_a?(Hash)

    hash = {}
    value.each do |class_name, opts|
      hash[class_name.to_s] = deep_symbolize_keys(opts)
    end
    hash
  end

  def deep_symbolize_keys(hash)
    return hash unless hash.is_a?(Hash)

    hash.each_with_object({}) do |(key, value), memo|
      memo[key.to_sym] = deep_symbolize_keys(value)
    end
  end

  def config_from_yaml
    return {} unless config_path

    @config_from_yaml ||= if File.exist?(config_path)
      YAML.load_file(config_path)
    else
      raise BackgroundJob::InvalidConfigError, "The file #{config_path} does not exist."
    end
    @config_from_yaml || {}
  end
end
