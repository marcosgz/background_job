# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackgroundJob::Configuration::Sidekiq do
  describe "#workers" do
    it "returns a hash" do
      expect(described_class.new.workers).to be_a(Hash)
    end

    it "normalizes the workers" do
      config = described_class.new
      config.workers = {"foo" => {"queue" => "bar"}}
      expect(config.workers["foo"]).to eq(queue: "bar")
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

    it "returns nil" do
      expect(described_class.new.redis).to be_nil
    end

    it "sets the redis" do
      config = described_class.new
      config.redis = redis
      expect(config.redis).to be(redis)
    end
  end
end
