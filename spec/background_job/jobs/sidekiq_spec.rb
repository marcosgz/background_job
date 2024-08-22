# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'BackgroundJob::Jobs::Sidekiq' do
  let(:described_class) { BackgroundJob::Jobs::Sidekiq }
  let(:job_class) { 'DummyWorker' }
  let(:job_args) { ['User', 1] }
  let(:job_opts) { {} }
  let(:job) do
    described_class
      .new(job_class, **job_opts)
      .with_args(*job_args)
  end
  let(:redis_dataset) do
    {
      standard_name: job.send(:immediate_queue_name),
      scheduled_name: job.send(:scheduled_queue_name),
      queues_set_name: job.send(:queues_set_name),
    }
  end

  before do
    BackgroundJob.config.sidekiq.jobs[job_class] = {}
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
        BackgroundJob.config.sidekiq.jobs[job_class] = { queue: 'mailer' }
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

  describe '"class" payload key' do
    it 'adds the class name to payload' do
      expect(job.payload["class"]).to eq(job_class)
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
        expect(job.payload["retry"]).to eq(true)
      end
    end

    context 'with retry option from mixin' do
      before do
        BackgroundJob.config.sidekiq.jobs[job_class] = { retry: 3 }
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
    subject(:push!) { job.push }

    let(:job_id) { '123' }
    let(:now) { Time.now.to_f }

    before do
      job.with_job_jid(job_id)
    end

    context 'with a standard job' do
      it 'adds a valid sidekiq hash to redis' do
        redis do |conn|
          conn.del(redis_dataset[:standard_name])
          conn.del(redis_dataset[:scheduled_name])
          expect(conn.llen(redis_dataset[:standard_name])).to eq(0)
          expect(conn.zcount(redis_dataset[:scheduled_name], 0, now + DAY_IN_SECONDS)).to eq(0)

          result = push!
          expect(result).to eq(
            'args' => job_args,
            'class' => job_class,
            'jid' => job_id,
            'created_at' => Time.now.to_f,
            'enqueued_at' => Time.now.to_f,
            'queue' => 'default',
            'retry' => true,
          )
          expect(conn.llen(redis_dataset[:standard_name])).to eq(1)
          expect(conn.zcount(redis_dataset[:scheduled_name], 0, now + DAY_IN_SECONDS)).to eq(0)

          raw_payload = conn.lpop(redis_dataset[:standard_name])
          expect(MultiJson.dump(result, mode: :compat)).to eq(raw_payload)
        end
      end

      it 'adds the queue to the list of queues' do
        redis do |conn|
          conn.del(redis_dataset[:queues_set_name])
          expect(conn.sismember(redis_dataset[:queues_set_name], 'default')).to eq(false)

          push!

          expect(conn.sismember(redis_dataset[:queues_set_name], 'default')).to eq(true)
        end
      end

      it 'retries for 3 times when the connection is read-only' do
        allow_any_instance_of(Redis).to receive(:pipelined).and_raise(Redis::CommandError, 'READONLY You can\'t write against a read only replica.')
        expect_any_instance_of(Redis).to receive(:close).exactly(3).times.and_call_original

        expect { push! }.to raise_error(Redis::CommandError)
      end
    end

    context 'with a scheduled job' do
      let(:job_opts) { { queue: 'mailer' } }

      before do
        job.at(Time.now + HOUR_IN_SECONDS)
      end

      it 'adds a valid sidekiq hash to redis' do
        redis do |conn|
          conn.del(redis_dataset[:standard_name])
          conn.del(redis_dataset[:scheduled_name])
          expect(conn.llen(redis_dataset[:standard_name])).to eq(0)
          expect(conn.zcount(redis_dataset[:scheduled_name], 0, now + DAY_IN_SECONDS)).to eq(0)

          result = push!
          expect(result).to eq(
            'args' => job_args,
            'class' => job_class,
            'jid' => job_id,
            'created_at' => Time.now.to_f,
            'queue' => 'mailer',
            'retry' => true,
          )
          expect(conn.llen(redis_dataset[:standard_name])).to eq(0)
          expect(conn.zcount(redis_dataset[:scheduled_name], 0, now + DAY_IN_SECONDS)).to eq(1)

          raw_payload = conn.zrangebyscore(redis_dataset[:scheduled_name], now, '+inf')[0]
          expect(MultiJson.dump(result, mode: :compat)).to eq(raw_payload)
        end
      end
    end
  end

  def redis
    BackgroundJob.config.sidekiq.redis_pool.with do |conn|
      yield conn
    end
  end
end
