# frozen_string_literal: true

require 'spec_helper'
require 'background_job/middleware/unique_job'

RSpec.describe BackgroundJob::Middleware::UniqueJob, freeze_at: [2020, 7, 2, 12, 30, 50] do
  describe '.bootstrap' do
    before do
      reset_config!
    end

    after do
      reset_config!
    end

    it 'loads and configure the external middleware for :sidekiq' do
      expect(BackgroundJob.config.sidekiq).not_to be_unique_job_active
      described_class.bootstrap(service: :sidekiq)
      expect { BackgroundJob.const_get('Middleware::UniqueJob::Sidekiq::Worker') }.not_to raise_error
      expect(BackgroundJob.config.sidekiq).to be_unique_job_active
      expect(BackgroundJob.config.sidekiq.middleware.exists?(described_class)).to eq(true)
    end

    it 'loads and configure the external middleware for :faktory' do
      expect(BackgroundJob.config.faktory).not_to be_unique_job_active
      described_class.bootstrap(service: :faktory)
      expect { BackgroundJob.const_get('Middleware::UniqueJob::Faktory::Worker') }.not_to raise_error
      expect(BackgroundJob.config.faktory).to be_unique_job_active
      expect(BackgroundJob.config.faktory.middleware.exists?(described_class)).to eq(true)
    end

    it 'does not load UniqueJob middleware and raise an error' do
      expect { described_class.bootstrap(service: :invalid) }.to raise_error(
        BackgroundJob::Error,
        /UniqueJob is not supported for the `:invalid' service/
      )
    end
  end

  describe '.unique_job_lock_id' do
    let(:job) { BackgroundJob::Jobs::Job.new('DummyWorker') }

    specify do
      expect(described_class.new.send(:unique_job_lock_id, job)).to eq(
        Digest::SHA256.hexdigest('["DummyWorker",[]]'),
      )
    end

    specify do
      expect(described_class.new.send(:unique_job_lock_id, job.with_args(1))).to eq(
        Digest::SHA256.hexdigest('["DummyWorker",[1]]'),
      )
    end

    specify do
      expect(described_class.new.send(:unique_job_lock_id, job.with_args(user_id: 1))).to eq(
        Digest::SHA256.hexdigest('["DummyWorker",[{"user_id":1}]]'),
      )
    end
  end

  describe '.unique_job_lock', freeze_at: [2020, 7, 1, 22, 24, 40] do
    specify do
      job = BackgroundJob::Jobs::Job.new('DummyWorker')
      expect(described_class.new.send(:unique_job_lock, job: job, service: :sidekiq)).to eq(nil)
    end

    specify do
      job = BackgroundJob::Jobs::Job.new('DummyWorker', uniq: true)
      job_lock = described_class.new.send(:unique_job_lock, job: job, service: :sidekiq)

      expect(job_lock).to be_an_instance_of(BackgroundJob::Lock)
    end

    specify do
      job = BackgroundJob::Jobs::Job.new('DummyWorker', uniq: true, service: :sidekiq)
      job_lock = described_class.new.send(:unique_job_lock, job: job, service: :sidekiq)

      expect(job_lock).to eq(described_class.new.send(:unique_job_lock, job: job, service: :sidekiq))
      expect(job_lock).not_to eq(described_class.new.send(:unique_job_lock, job: job, service: :faktory))
    end
  end

end
