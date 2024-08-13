# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BackgroundJob do
  describe '.jid class method' do
    specify do
      expect(described_class.jid).to be_a_kind_of(String)
      expect(described_class.jid).not_to eq(described_class.jid)
      expect(described_class.jid.size).to eq(24)
    end
  end

  describe '.config class method' do
    it { expect(described_class.config).to be_an_instance_of(BackgroundJob::Config) }
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
