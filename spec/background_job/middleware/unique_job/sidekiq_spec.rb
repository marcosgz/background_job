# frozen_string_literal: true

require 'spec_helper'
require 'background_job/middleware/unique_job'

RSpec.describe 'BackgroundJob::Middleware::UniqueJob::Sidekiq', freeze_at: [2020, 7, 2, 12, 30, 50] do
  let(:job_class) do
    Class.new do
      def self.name
        'DummyWorker'
      end
    end
  end
  let(:job) do
    BackgroundJob::Jobs::Sidekiq.new(job_class.name,
      queue: 'mailer',
    ).with_job_jid('dummy123')
  end
  let(:now) { Time.now.to_f }

  before do
    BackgroundJob.configure { |c| c.sidekiq.jobs = { 'DummyWorker' => {} } }
  end

  shared_examples 'unique job across' do |across|
    subject(:push!) { job.push }

    context "with a unique job across #{across}" do
      let(:lock_digest) do
        BackgroundJob::LockDigest.new(:sidekiq, :mailer, across: across).to_s
      end

      before do
        job.unique(across: across, timeout: HOUR_IN_SECONDS)
      end

      it 'does not push job when active uniqueness lock exist' do
        redis do |conn|
          conn.del(sidekiq_immediate_name)
          expect(conn.llen(sidekiq_immediate_name)).to eq(0)
          conn.del(lock_digest)
          expect(conn.zcount(lock_digest, 0, now + DAY_IN_SECONDS)).to eq(0)

          # Adds a lock_id
          lock_id = Digest::SHA256.hexdigest('["DummyWorker",[]]')
          conn.zadd(lock_digest, now+1, lock_id)
          conn.zadd(lock_digest, now-2, '123')
          conn.zadd(lock_digest, now-1, '456')
          expect(conn.zcount(lock_digest, 0, now + DAY_IN_SECONDS)).to eq(3)

          result = push!
          expect(result).to eq(false)
          expect(conn.zcount(lock_digest, 0, now + DAY_IN_SECONDS)).to eq(1)
          ttl = conn.zscore(lock_digest, lock_id)
          expect(ttl.to_i).to eq(now.to_i+1)

          updated_job = job.payload.merge(
            'uniq' => {
              'across' => across.to_s,
              'timeout' => 3_600,
              'unlock_policy' => 'success',
              'lock' => {
                'ttl' => now + 3_600,
                'digest' => lock_digest,
                'lock_id' => lock_id,
              }
            }
          )

          # Removes the lock after job execution
          expect { |y| BackgroundJob::Middleware::UniqueJob::Sidekiq::Worker.new.call(job_class, updated_job, 'mailer', &y) }.to yield_control
          expect(conn.zcount(lock_digest, 0, now + DAY_IN_SECONDS)).to eq(0)
        end
      end

      it 'adds a lock with 1 hour of TTL and enqueues a new job' do
        redis do |conn|
          conn.del(sidekiq_immediate_name)
          expect(conn.llen(sidekiq_immediate_name)).to eq(0)
          conn.del(lock_digest)
          expect(conn.zcount(lock_digest, 0, now + DAY_IN_SECONDS)).to eq(0)

          result = push!
          expect(result.dig('uniq', 'across')).to eq(across.to_s)
          expect(result.dig('uniq', 'timeout')).to eq(3_600)
          expect(result.dig('uniq', 'unlock_policy')).to eq('success')
          expect(result.dig('uniq', 'lock', 'ttl')).to eq(now + 3_600)
          expect(result.dig('uniq', 'lock', 'digest')).to eq(lock_digest)
          expect(result.dig('uniq', 'lock', 'lock_id')).to be_a_kind_of(String)

          expect(conn.llen(sidekiq_immediate_name)).to eq(1)
          expect(conn.zcount(lock_digest, 0, now + DAY_IN_SECONDS)).to eq(1)

          lock_id = conn.zrangebyscore(lock_digest, now + 3_600, now + 3_600)[0]
          expect(lock_id).to be_a_kind_of(String)
          expect(result.dig('uniq', 'lock', 'lock_id')).to eq(lock_id)

          # Adds more expired jobs to be flushed
          conn.zadd(lock_digest, now-2, '123')
          conn.zadd(lock_digest, now-1, '456')
          travel_to = Time.now + HOUR_IN_SECONDS + 1
          Timecop.travel(travel_to) do
            new_result = job.push
            expect(conn.llen(sidekiq_immediate_name)).to eq(2)
            expect(conn.zcount(lock_digest, 0, now + DAY_IN_SECONDS)).to eq(1)
            ttl = conn.zscore(lock_digest, lock_id)
            expect(ttl.to_i).to eq(travel_to.to_i + 3_600)

            # Removes the lock after job execution
            expect { |y| BackgroundJob::Middleware::UniqueJob::Sidekiq::Worker.new.call(job_class, result, 'mailer', &y) }.to yield_control
            expect(conn.zcount(lock_digest, 0, now + DAY_IN_SECONDS)).to eq(0)
          end
        end
      end
    end
  end

  describe '.call' do
    before do
      BackgroundJob::Middleware::UniqueJob.bootstrap(service: :sidekiq)
    end

    after do
      BackgroundJob.config.sidekiq.middleware.clear
    end

    it_behaves_like('unique job across', :queue)
    it_behaves_like('unique job across', :systemwide)
  end

  def redis
    BackgroundJob.config.redis_pool.with do |conn|
      yield conn
    end
  end

  def sidekiq_immediate_name
    [BackgroundJob.config.sidekiq.namespace, 'queue', 'mailer'].compact.join(':')
  end
end
