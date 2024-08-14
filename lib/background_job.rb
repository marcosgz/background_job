# frozen_string_literal: true

require 'yaml'
require 'time'
require 'securerandom'
require 'multi_json'

require_relative 'background_job/version'
require_relative 'background_job/errors'
require_relative "background_job/redis_pool"
require_relative 'background_job/mixin'
require_relative 'background_job/jobs'
require_relative 'background_job/configuration'
# require_relative 'background_job/adapters/adapter'
# require_relative 'background_job/adapters/sidekiq'
# require_relative 'background_job/adapters/faktory'

# This is a central point of our background job enqueuing system.
# Example:
#
# Standard job.
#   BackgroundJob.sidekiq('UserWorker', queue: 'default')
#     .with_args(1)
#     .push
# Schedule the time when a job will be executed.
#   BackgroundJob.sidekiq('UserWorker')
#     .with_args(1)
#     .at(timestamp)
#     .push
#   BackgroundJob.sidekiq('UserWorker')
#     .with_args(1)
#     .in(10.minutes)
#     .push
#
# Unique jobs.
#   BackgroundJob.sidekiq('UserWorker', uniq: { across: :queue, timeout: 1.minute, unlock_policy: :start })
#     .with_args(1)
#     .push
module BackgroundJob
  SERVICES = {
    sidekiq: 'Sidekiq',
    faktory: 'Faktory',
  }.freeze

  SERVICES.each do |id, name|
    define_singleton_method(id) do |job_name, **options|
      Jobs.const_get(name).new(job_name, **options)
    end
  end

  def self.mixin(service, **options)
    service = service.to_sym
    unless SERVICES.key?(service)
      raise Error, "Service `#{service}' is not supported. Supported services are: #{SERVICES.keys.join(', ')}"
    end
    require_relative "background_job/mixin/#{service}"
    require_relative "background_job/jobs/#{service}"

    module_name = service.to_s.split(/_/i).collect!{ |w| w.capitalize }.join
    mod = Mixin.const_get(module_name)
    mod::Builder.new(**options)
  end

  def self.jid
    SecureRandom.hex(12)
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure(&block)
    return unless block_given?

    config.instance_eval(&block) if block_given?
    config
  end

  def self.config_for(service)
    service = service.to_sym
    unless SERVICES.key?(service)
      raise Error, "Service `#{service}' is not supported. Supported services are: #{SERVICES.keys.join(', ')}"
    end
    config.send(service)
  end
end
