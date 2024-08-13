# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'BackgroundJob errors' do

  describe 'BackgroundJob::NotDefinedJobError' do
    specify do
      msg = <<~MSG.chomp
      The "MissingWorker" is not defined and the BackgroundJob is configured to work on strict mode.
      it's highly recommended to include this worker class to the list of known workers.
      Example: `BackgroundJob.configure { |config| config.sidekiq.workers = { "MissingWorker" => {} } }`
      Another option is to set config.strict = false
      MSG

      error = BackgroundJob::NotDefinedJobError.new('MissingWorker')
      expect(error.message).to eq(msg)
    end
  end

  describe 'BackgroundJob::InvalidConfigError' do
    specify do
      error = BackgroundJob::InvalidConfigError.new('Invalid YAML')
      expect(error.message).to eq('Invalid YAML')
    end
  end
end
