# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackgroundJob::Configuration::Sidekiq do
  describe "#jobs" do
    it "returns a hash" do
      expect(described_class.new.jobs).to be_a(Hash)
    end

    it "normalizes the jobs" do
      config = described_class.new
      config.jobs = {"foo" => {"queue" => "bar"}}
      expect(config.jobs["foo"]).to eq(queue: "bar")
    end
  end

  describe "#namespace" do
    it "returns nil as the default namespace" do
      expect(described_class.new.namespace).to be_nil
    end
  end

  describe "#namespace=" do
    it "sets the namespace" do
      config = described_class.new
      config.namespace = "foo"
      expect(config.namespace).to eq("foo")
    end
  end

  describe "#redis_pool" do
    it "returns a redis pool from global config" do
      config = described_class.new
      expect(config.redis_pool).to be_a(BackgroundJob::RedisPool)
      expect(config.redis_pool).to be(BackgroundJob.config.redis_pool)
    end

    it "returns a redis pool from the configuration" do
      config = described_class.new
      config.redis = { url: "redis://localhost" }
      expect(config.redis_pool).to be_a(BackgroundJob::RedisPool)
    end
  end

  describe "#redis" do
    let(:redis) { instance_double(::Redis) }
    let(:config) { described_class.new }

    before do
      allow(redis).to receive(:is_a?).with(::Redis).and_return(true)
    end

    it "returns nil" do
      expect(config.redis).to be_nil
    end

    it "sets the redis" do
      config.redis = redis
      expect(config.redis).to be(redis)
    end

    it "redefines a new pool when redis is set" do
      pool = config.redis_pool
      config.redis = redis
      expect(config.redis_pool).not_to be(pool)
      expect(config.redis_pool).to be_a(BackgroundJob::RedisPool)
    end
  end

  describe "#update_queues!" do
    let(:config) { described_class.new }

    before do
      config.redis_pool.with { |conn| conn.del("queues") }
    end

    context "without namespace" do
      it "updates the queues" do
        config.jobs = {
          "FooJob" => { queue: "foo" },
          "BarJob" => { queue: "bar" },
        }
        config.redis = Redis.new
        config.update_queues!

        expect(config.redis_pool.with { |conn| conn.smembers("queues") }).to match_array(%w[foo bar])
      end
    end

    context "with namespace" do
      it "updates the queues" do
        config.jobs = {
          "FooJob" => { queue: "foo" },
          "BarJob" => { queue: "bar" },
        }
        config.redis = Redis.new
        config.namespace = "test"
        config.update_queues!

        expect(config.redis_pool.with { |conn| conn.smembers("test:queues") }).to match_array(%w[foo bar])
      end
    end
  end
end
