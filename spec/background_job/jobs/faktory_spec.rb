# frozen_string_literal: true

require 'spec_helper'
require 'faktory'

RSpec.describe 'BackgroundJob::Jobs::Faktory' do
  let(:described_class) { BackgroundJob::Jobs::Faktory }
  let(:job_class) { 'DummyWorker' }
  let(:job_args) { ['User', 1] }
  let(:job_opts) { {} }
  let(:job) do
    described_class
      .new(job_class, **job_opts)
      .with_args(*job_args)
  end

  before do
    BackgroundJob.config.faktory.jobs[job_class] = {}
  end

  after do
    reset_config!
  end

  describe '"queue" payload key' do
    context 'without queue option' do
      it 'adds the global queue to payload' do
        expect(job.payload["queue"]).to eq("default")
      end
    end

    context 'with queue option from mixin' do
      before do
        BackgroundJob.config.faktory.jobs[job_class] = { queue: 'mailer' }
      end

      it 'adds the global queue to payload' do
        expect(job.payload["queue"]).to eq("mailer")
      end
    end

    context 'with queue option from instance' do
      let(:job_opts) { { queue: 'high_priority' } }

      it 'adds the global queue to payload' do
        expect(job.payload["queue"]).to eq("high_priority")
      end
    end
  end

  describe '"jobtype" payload key' do
    it 'adds the class name to payload' do
      expect(job.payload["jobtype"]).to eq(job_class)
    end
  end

  describe '"args" payload key' do
    it 'adds the args to payload' do
      expect(job.with_args('foo').payload["args"]).to eq(['foo'])
    end
  end

  describe '"created_at" payload key', freeze_at: [2020, 7, 2, 12, 30, 50] do
    it 'adds the current time to payload' do
      expect(job.payload["created_at"]).to eq(Time.now.to_f)
    end
  end

  describe '"retry" payload key' do
    context 'without retry option' do
      it 'adds the global retry to payload' do
        expect(job.payload["retry"]).to eq(25)
      end
    end

    context 'with retry option from mixin' do
      before do
        BackgroundJob.config.faktory.jobs[job_class] = { retry: 3 }
      end

      it 'adds the global retry to payload' do
        expect(job.payload["retry"]).to eq(3)
      end
    end

    context 'with retry option from instance' do
      let(:job_opts) { { retry: 5 } }

      it 'adds the global retry to payload' do
        expect(job.payload["retry"]).to eq(5)
      end
    end
  end

  describe '#push', freeze_at: [2020, 7, 2, 12, 30, 50] do
    let(:job_id) { 'dummy123' }

    before do
      BackgroundJob.config.faktory.jobs[job_class] = {}
      require 'faktory/testing'
      Faktory::Testing.fake!
      job.with_job_jid(job_id)
    end

    after do
      reset_config!

      Faktory::Queues.clear_all
      Faktory::Testing.disable!
    end

    subject(:push!) { job.push }

    let(:now) { Time.now.to_f }

    context 'with a standard job' do
      it 'adds a valid payload to faktory' do
        result = push!
        expect(result).to eq(
          'args' => job_args,
          'jobtype' => job_class,
          'jid' => job_id,
          'created_at' => Time.now.to_datetime.rfc3339(9),
          'enqueued_at' => Time.now.to_datetime.rfc3339(9),
          'queue' => 'default',
          'retry' => 25,
        )
        expect(Faktory::Queues['default'].size).to eq(1)
      end
    end

    context 'with a scheduled job' do
      let(:job_opts) { { queue: 'mailer' } }

      before do
        job.at(Time.now + HOUR_IN_SECONDS)
      end

      it 'adds a valid payload to faktory' do
        result = push!
        expect(result).to eq(
          'args' => job_args,
          'jobtype' => job_class,
          'jid' => job_id,
          'at' => (Time.now + HOUR_IN_SECONDS).to_datetime.rfc3339(9),
          'created_at' => Time.now.to_datetime.rfc3339(9),
          'enqueued_at' => Time.now.to_datetime.rfc3339(9),
          'queue' => 'mailer',
          'retry' => 25,
        )
        expect(Faktory::Queues['default'].size).to eq(0)
        expect(Faktory::Queues['mailer'].size).to eq(1)
      end
    end
  end
end
