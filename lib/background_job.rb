# frozen_string_literal: true

require 'yaml'
require 'time'
require 'securerandom'
require 'multi_json'

require_relative 'background_job/version'
require_relative 'background_job/errors'
require_relative "background_job/redis_pool"
require_relative 'background_job/configuration'
require_relative 'background_job/worker'
require_relative 'background_job/adapters/adapter'
require_relative 'background_job/adapters/sidekiq'
require_relative 'background_job/adapters/faktory'

# This is a central point of our background job queue system.
# We have more external services like API and Lme that queue jobs for pipeline processing.
# So that way all services can share the same codebase and avoid incompatibility issues
#
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
end
