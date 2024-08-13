# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackgroundJob::Configuration::Base do
  let(:worker_class) { Class.new(described_class) }
  let(:config) { worker_class.new }

  describe '.worker_options' do
    before do
      config.workers = {
        'DummyWorker' => { 'queue' => 'mailing' }
      }
    end

    after { reset_config! }

    it 'returns an empty hash as default' do
      config.strict = false
      expect(config.worker_options('MissingWorker')).to eq({})
    end

    it 'retrieves the options from workers using class_name' do
      config.strict = true
      expect(config.worker_options('DummyWorker')).to eq(queue: 'mailing')
    end

    it 'raises NotDefinedWorker when on strict mode' do
      config.strict = true

      expect { config.worker_options('MissingWorker') }.to raise_error(BackgroundJob::NotDefinedJobError)
    end
  end

  describe '.attribute_accessor from yaml' do
    context 'when the file is not set' do
      it 'returns nil' do
        config.config_path = nil
        expect(config.workers).to eq({})
      end
    end

    context 'when the file exists' do
      let(:config_path) { File.expand_path('spec/fixtures/config.yml') }

      it 'loads the values from the file' do
        config.config_path = config_path
        expect(config.workers).to eq({
          'DummyWorker' => { queue: 'mailing' }
        })
      end
    end

    context 'when the file is not a valid YAML' do
      let(:config_path) { File.expand_path('spec/fixtures/invalid.yml') }

      it 'raises an error' do
        config.config_path = config_path
        expect { config.workers }.to raise_error(BackgroundJob::InvalidConfigError)
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
