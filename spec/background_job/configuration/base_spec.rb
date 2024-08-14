# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackgroundJob::Configuration::Base do
  let(:worker_class) { Class.new(described_class) }
  let(:config) { worker_class.new }

  describe '.job_options' do
    before do
      config.jobs['DummyWorker'] = { 'queue' => 'mailing' }
    end

    after { reset_config! }

    it 'does not raise an error' do
      expect(config.validate_strict_job!('DummyWorker')).to eq(true)
    end

    it 'raises NotDefinedWorker when on strict mode' do
      config.strict = true

      expect { config.validate_strict_job!('MissingWorker') }.to raise_error(BackgroundJob::NotDefinedJobError)
    end
  end

  describe '.attribute_accessor from yaml' do
    context 'when the file is not set' do
      it 'returns nil' do
        config.config_path = nil
        expect(config.jobs).to eq({})
      end
    end

    context 'when the file exists' do
      let(:config_path) { File.expand_path('spec/fixtures/config.yml') }

      it 'loads the values from the file' do
        config.config_path = config_path
        expect(config.jobs).to eq({
          'DummyWorker' => { queue: 'mailing' }
        })
      end
    end

    context 'when the file is not a valid YAML' do
      let(:config_path) { File.expand_path('spec/fixtures/invalid.yml') }

      it 'raises an error' do
        config.config_path = config_path
        expect { config.jobs }.to raise_error(BackgroundJob::InvalidConfigError)
      end
    end
  end

  describe '.middleware' do
    let(:middleware) do
      Class.new do
        def call(job, conn_pool)
          yield
        end
      end
    end

    it 'returns a MiddlewareChain' do
      expect(config.middleware).to be_a(BackgroundJob::Configuration::MiddlewareChain)
    end

    it 'yields the middleware chain' do
      config.middleware do |chain|
        chain.add middleware
      end

      expect(config.middleware.to_a).to match_array(
        be_a(BackgroundJob::Configuration::MiddlewareChain::Entry)
      )
    end
  end
end
