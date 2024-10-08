require 'spec_helper'

RSpec.describe BackgroundJob::Lock, freeze_at: [2020, 7, 1, 22, 24, 40] do
  let(:ttl) { Time.now.to_f + HOUR_IN_SECONDS }
  let(:digest) { ['bgjb', 'test', 'uniqueness-lock'].join(':') }
  let(:lock_id) { 'abc123' }
  let(:model) { described_class.new(digest: digest, ttl: ttl, lock_id: lock_id) }

  describe '.coerce' do
    specify do
      expect(described_class.coerce(nil)).to eq(nil)
      expect(described_class.coerce(false)).to eq(nil)
      expect(described_class.coerce(true)).to eq(nil)
      expect(described_class.coerce('')).to eq(nil)
      expect(described_class.coerce(1)).to eq(nil)
    end

    specify do
      expect(described_class.coerce(ttl: ttl, digest: digest, lock_id: lock_id)).to eq(
        described_class.new(ttl: ttl, digest: digest, lock_id: lock_id)
      )
    end

    specify do
      expect(described_class.coerce('ttl' => ttl, 'digest' => digest, 'lock_id' => lock_id)).to eq(
        described_class.new(ttl: ttl, digest: digest, lock_id: lock_id)
      )
    end

    specify do
      expect(described_class.coerce('ttl' => nil, 'digest' => digest, 'lock_id' => lock_id)).to eq(nil)
      expect(described_class.coerce('ttl' => ttl, 'digest' => nil, 'lock_id' => lock_id)).to eq(nil)
      expect(described_class.coerce('ttl' => ttl, 'digest' => digest, 'lock_id' => nil)).to eq(nil)
    end
  end

  describe '.to_hash' do
    subject { model.to_hash }

    specify do
      is_expected.to eq(
        'digest' => digest.to_s,
        'ttl' => ttl,
        'lock_id' => lock_id.to_s,
      )
    end
  end

  describe '.lock' do
    specify do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
        expect(conn.zcount(digest, 0, ttl)).to eq(0)

        expect(model.lock).to eq(true)
        expect(conn.zcount(digest, 0, ttl)).to eq(1)
        expect(model.lock).to eq(false)
        expect(conn.zcount(digest, 0, ttl)).to eq(1)
      end
    end

    specify do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
        expect(model.lock).to eq(true)

        travel_to = Time.at(ttl)
        expect(conn.zcount(digest, 0, ttl)).to eq(1)

        Timecop.travel(travel_to) do
          new_ttl = ttl + HOUR_IN_SECONDS
          new_model = described_class.new(digest: model.digest, lock_id: model.lock_id, ttl: new_ttl)
          expect(new_model.lock).to eq(false)
          expect(conn.zcount(digest, 0, new_ttl)).to eq(1)
          expect(conn.zcount(digest, 0, ttl)).to eq(0)
        end
      end
    end
  end

  describe '.unlock' do
    specify do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
        expect(conn.zcount(digest, 0, ttl)).to eq(0)
        expect(model.unlock).to eq(false)

        conn.zadd(digest, ttl, lock_id)
        expect(conn.zcount(digest, 0, ttl)).to eq(1)

        expect(model.unlock).to eq(true)
        expect(conn.zcount(digest, 0, ttl)).to eq(0)
      end
    end
  end

  describe '.locked?' do
    specify do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
        expect(model.locked?).to eq(false)

        conn.zadd(digest, ttl, lock_id)
        expect(model.locked?).to eq(true)

        expect(model.unlock).to eq(true)
        expect(model.locked?).to eq(false)
      end
    end

    specify do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
        expect(model.locked?).to eq(false)

        conn.zadd(digest, ttl, lock_id)
        expect(model.locked?).to eq(true)

        travel_to = Time.at(ttl)
        expect(conn.zcount(digest, 0, travel_to.to_f)).to eq(1)
        Timecop.travel(travel_to) do
          expect(model.locked?).to eq(false)
          expect(conn.zcount(digest, 0, travel_to.to_f)).to eq(0)
        end
      end
    end
  end

  describe '.flush_expired_members class method' do
    specify do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
      end
      expect { described_class.flush_expired_members(digest) }.not_to raise_error
    end

    specify do
      expect { described_class.flush_expired_members(nil) }.not_to raise_error
    end

    specify do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
        expect { described_class.flush_expired_members(digest, redis: conn) }.not_to raise_error
        expect { described_class.flush_expired_members(nil, redis: conn) }.not_to raise_error
      end
    end

    specify do
      BackgroundJob.config.redis_pool.with do |conn|
        lock_queue1 = described_class.new(digest: digest + '1', ttl: ttl, lock_id: lock_id).tap(&:lock)
        lock_queue2 = described_class.new(digest: digest + '2', ttl: ttl, lock_id: lock_id).tap(&:lock)
        expect(conn.zcount(lock_queue1.digest, 0, ttl)).to eq(1)
        expect(conn.zcount(lock_queue2.digest, 0, ttl)).to eq(1)

        described_class.flush_expired_members(lock_queue1.digest)
        expect(conn.zcount(lock_queue1.digest, 0, ttl)).to eq(1)
        expect(conn.zcount(lock_queue2.digest, 0, ttl)).to eq(1)

        travel_to = Time.at(ttl)
        Timecop.travel(travel_to) do
          described_class.flush_expired_members(lock_queue1.digest)
          expect(conn.zcount(lock_queue1.digest, 0, ttl)).to eq(0)
          expect(conn.zcount(lock_queue2.digest, 0, ttl)).to eq(1)
        end
      end
    end
  end

  describe '.flush class method' do
    it 'does not raise an error when the digest does not exist' do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
        expect(described_class.count(digest, redis: conn)).to eq(0)
      end
      expect(described_class.count(digest)).to eq(0)
    end

    it 'filters the range acording to the ttl' do
      described_class.new(digest: digest, ttl: ttl-1, lock_id: lock_id+'a').lock
      described_class.new(digest: digest+'x', ttl: ttl, lock_id: lock_id+'b').lock
      described_class.new(digest: digest, ttl: ttl+1, lock_id: lock_id+'c').lock

      expect(described_class.count(digest)).to eq(2)
      expect(described_class.count(digest, from: ttl+1)).to eq(1)
      expect(described_class.count(digest, to: ttl-1)).to eq(1)
      expect(described_class.count(digest+'x', from: ttl, to: ttl)).to eq(1)
      expect(described_class.count(digest, from: ttl, to: ttl)).to eq(0)
    end
  end

  describe '.flush class method' do
    it 'does not raise an error when the digest does not exist' do
      BackgroundJob.config.redis_pool.with do |conn|
        conn.del(digest)
        expect { described_class.flush(digest, redis: conn) }.not_to raise_error
      end
      expect { described_class.flush(digest) }.not_to raise_error
    end

    it 'removes all locks without redis argument' do
      described_class.new(digest: digest, ttl: ttl, lock_id: lock_id + '1').lock
      described_class.new(digest: digest, ttl: ttl, lock_id: lock_id + '2').lock

      BackgroundJob.config.redis_pool.with do |conn|
        expect(conn.zcount(digest, 0, ttl + WEEK_IN_SECONDS)).to be >= 2
        expect { described_class.flush(digest) }.not_to raise_error
        expect(conn.zcount(digest, 0, ttl + WEEK_IN_SECONDS)).to eq(0)
      end
    end

    it 'removes all locks using connection from arguments' do
      described_class.new(digest: digest, ttl: ttl, lock_id: lock_id + '1').lock
      described_class.new(digest: digest, ttl: ttl, lock_id: lock_id + '2').lock

      BackgroundJob.config.redis_pool.with do |conn|
        expect(conn.zcount(digest, 0, ttl + WEEK_IN_SECONDS)).to be >= 2
        expect { described_class.flush(digest, redis: conn) }.not_to raise_error
        expect(conn.zcount(digest, 0, ttl + WEEK_IN_SECONDS)).to eq(0)
      end
    end
  end
end
