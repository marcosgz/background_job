require 'spec_helper'
require 'background_job/lock_digest'

RSpec.describe BackgroundJob::LockDigest do
  describe '.to_s' do
    specify do
      expect(described_class.new('foo', across: :queue).to_s).to eq('bgjb:uniq:foo')
      expect(described_class.new('sidekiq', 'foo', across: :queue).to_s).to eq('bgjb:uniq:sidekiq:foo')
    end

    specify do
      expect(described_class.new('foo', across: :systemwide).to_s).to eq('bgjb:uniq')
      expect(described_class.new('sidekiq', 'foo', across: :systemwide).to_s).to eq('bgjb:uniq:sidekiq')
    end

    specify do
      expect{ described_class.new('foo', across: :undefined).to_s }.to raise_error(
        BackgroundJob::Error,
        'Could not resolve the lock digest using across :undefined. Valid options are :systemwide and :queue',
      )
      expect{ described_class.new('sidekiq', 'foo', across: :undefined).to_s }.to raise_error(BackgroundJob::Error)
    end
  end
end
