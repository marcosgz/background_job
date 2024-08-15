# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackgroundJob::Configuration do
  describe "#redis_pool" do
    it "returns a redis pool" do
      config = described_class.new
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

  describe "#faktory" do
    it "returns an instance of BackgroundJob::Configuration::Faktory" do
      expect(described_class.new.faktory).to be_a(BackgroundJob::Configuration::Faktory)
    end

    it "yields the configuration" do
      described_class.new.faktory do |config|
        expect(config).to be_a(BackgroundJob::Configuration::Faktory)
      end
    end
  end

  describe "#sidekiq" do
    it "returns an instance of BackgroundJob::Configuration::Sidekiq" do
      expect(described_class.new.sidekiq).to be_a(BackgroundJob::Configuration::Sidekiq)
    end

    it "yields the configuration" do
      described_class.new.sidekiq do |config|
        expect(config).to be_a(BackgroundJob::Configuration::Sidekiq)
      end
    end
  end

  describe "#services" do
    let(:instance) { described_class.new }

    it "returns an instance of BackgroundJob::ConfigService" do
      expect(instance.services).to be_a(BackgroundJob::ConfigService)
    end

    it "returns true for sidekiq? if sidekiq is configured" do
      expect(instance.services.sidekiq?).to be(false)
      instance.sidekiq
      expect(instance.services.sidekiq?).to be(true)
    end

    it "returns true for faktory? if faktory is configured" do
      expect(instance.services.faktory?).to be(false)
      instance.faktory
      expect(instance.services.faktory?).to be(true)
    end
  end

  describe "#reset!" do
    it "resets the configuration" do
      config = described_class.new
      config.redis = instance_double(::Redis)
      config.faktory
      config.sidekiq
      config.reset!

      expect(config.redis).to be_nil
      expect(config.instance_variable_get(:@redis_pool)).to be_nil
      expect(config.instance_variable_get(:@services)).to be_nil
      expect(config.instance_variable_get(:@faktory)).to be_nil
      expect(config.instance_variable_get(:@sidekiq)).to be_nil
    end
  end
end
