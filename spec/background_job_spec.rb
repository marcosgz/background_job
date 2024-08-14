# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BackgroundJob do
  describe '.sidekiq class method' do
    after { reset_config! }

    context 'without definition' do
      specify do
        described_class.configure { |c| c.sidekiq.strict = false }

        job = described_class.sidekiq('DummyWorker')
        expect(job).to be_an_instance_of(BackgroundJob::Jobs::Sidekiq)
        expect(job.options).to be_a_kind_of(Hash)
      end
    end
  end

  describe '.faktory class method' do
    after { reset_config! }

    context 'without definition' do
      specify do
        described_class.configure { |c| c.faktory.strict = false }

        job = described_class.faktory('DummyWorker')
        expect(job).to be_an_instance_of(BackgroundJob::Jobs::Faktory)
        expect(job.options).to be_a_kind_of(Hash)
      end
    end
  end

  describe '.jid class method' do
    specify do
      expect(described_class.jid).to be_a_kind_of(String)
      expect(described_class.jid).not_to eq(described_class.jid)
      expect(described_class.jid.size).to eq(24)
    end
  end

  describe '.config class method' do
    it { expect(described_class.config).to be_an_instance_of(BackgroundJob::Configuration) }
  end

  describe '.config_for' do
    it 'returns the configuration for the given service' do
      expect(described_class.config_for(:sidekiq)).to be_an_instance_of(BackgroundJob::Configuration::Sidekiq)
      expect(described_class.config_for(:faktory)).to be_an_instance_of(BackgroundJob::Configuration::Faktory)
    end

    it 'raises an error when the service is not supported' do
      expect { described_class.config_for(:invalid) }.to raise_error(BackgroundJob::Error, /Service `invalid' is not supported/)
    end
  end

  describe '.configure' do
    after { reset_config! }

    it 'overwrites default config value' do
      described_class.config.redis = { url: 'redis://localhost:6379' }

      expect {
        described_class.configure { |config| config.redis = { url: 'redis://redis:6379' } }
      }.to change { described_class.config.redis[:url] }.from('redis://localhost:6379').to('redis://redis:6379')
    end

    it 'starts a fresh redis pool' do
      pool = described_class.config.redis_pool
      3.times { expect(described_class.config.redis_pool).to eql(pool) }
      described_class.configure { |config| config.redis = { url: 'redis://0.0.0.0:6379' } }
      expect(described_class.config.redis_pool).not_to eql(pool)
    end
  end
end
