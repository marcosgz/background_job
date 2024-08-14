# frozen_string_literal: true

require 'spec_helper'
require 'background_job/testing'

RSpec.describe 'testing mode' do
  before do
    BackgroundJob.config_for(:sidekiq) { |c| c.strict = false }
    BackgroundJob.config_for(:faktory) { |c| c.strict = false }
    BackgroundJob::Testing.enable!
  end

  after do
    BackgroundJob::Testing.disable!
    reset_config!
  end

  describe 'BackgroundJob::Testing' do
    it 'enables the testing mode' do
      expect(BackgroundJob::Testing.enabled?).to be(true)
    end

    it 'disables the testing mode' do
      BackgroundJob::Testing.disable!
      expect(BackgroundJob::Testing.disabled?).to be(true)
    end
  end

  describe 'BackgroundJob::Jobs' do
    it 'intercepts all the jobs' do
      BackgroundJob.sidekiq('MyWorker').with_args(1).push
      expect(BackgroundJob::Jobs.size).to eq(1)
      expect(BackgroundJob::Jobs.jobs).to all(be_a(BackgroundJob::Jobs::Job))
      BackgroundJob::Jobs.clear
      expect(BackgroundJob::Jobs.size).to eq(0)
    end

    it 'filters the jobs by service' do
      BackgroundJob.sidekiq('MySidekiqJob').with_args(1).push
      BackgroundJob.faktory('MyFaktoryJob').with_args(2).push

      expect(BackgroundJob::Jobs.jobs_for(service: :sidekiq).size).to eq(1)
      expect(BackgroundJob::Jobs.jobs_for(service: :faktory).size).to eq(1)

      expect(BackgroundJob::Jobs.jobs_for(class_name: 'MySidekiqJob').size).to eq(1)
      expect(BackgroundJob::Jobs.jobs_for(class_name: 'MyFaktoryJob').size).to eq(1)
    end
  end

end

