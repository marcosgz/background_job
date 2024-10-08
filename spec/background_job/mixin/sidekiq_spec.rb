# frozen_string_literal: true

require 'spec_helper'
require 'background_job/mixin/sidekiq'

RSpec.describe BackgroundJob::Mixin::Sidekiq do
  after do
    reset_config!
  end

  describe '.background_job_service' do
    let(:worker) do
      Class.new do
        extend BackgroundJob.mixin(:sidekiq)
      end
    end

    specify do
      expect(worker.background_job_service).to eq(:sidekiq)
    end
  end

  describe ".background_job_options" do
    let(:job_name) { 'Noop' }

    shared_examples 'assertions' do
      specify do
        expect(described_class.background_job_options(job_name)).to eq(
          queue: 'sidekiq_global',
          retry: 0,
        )
      end

      it 'replace the :queue from configurations' do
        BackgroundJob.config.sidekiq.jobs[job_name] = {
          queue: 'local_config',
        }
        expect(described_class.background_job_options(job_name)).to eq(
          queue: 'local_config',
          retry: 0,
        )
      end

      it 'replace the :retry from configurations' do
        BackgroundJob.config.sidekiq.jobs[job_name] = {
          retry: 10,
        }
        expect(described_class.background_job_options(job_name)).to eq(
          queue: 'sidekiq_global',
          retry: 10,
        )
      end
    end

    context 'with sidekiq < 7 available' do
      before do
        stub_const('Sidekiq', Class.new do
          def self.default_worker_options
            {
              'queue' => 'sidekiq_global',
              'retry' => 0,
            }
          end
        end)
      end

      include_examples 'assertions'
    end

    context 'with sidekiq >= 7 available' do
      before do
        stub_const('Sidekiq', Class.new do
          def self.default_job_options
            {
              'queue' => 'sidekiq_global',
              'retry' => 0,
            }
          end

          def self.default_worker_options
            {
              'queue' => 'sidekiq_global',
              'retry' => 0,
            }
          end
        end)
      end

      include_examples 'assertions'
    end

  end

  describe 'BackgroundJob#mixin' do
    context 'with default settings' do
      let(:worker) do
        Class.new do
          extend BackgroundJob.mixin(:sidekiq)

          def self.name
            'DummyWorker'
          end
        end
      end

      it 'includes enqueuing methods' do
        expect(worker).to respond_to(:perform_async)
        expect(worker).to respond_to(:perform_in)
        expect(worker).to respond_to(:perform_at)
      end

      it 'returns the default from Sidekiq' do
        expect(worker.background_job_default_options).to eq(
          queue: 'default',
          retry: true,
        )
      end

      it 'returns an empty hash as default for user options' do
        expect(worker.background_job_user_options).to be_a_kind_of(Hash)
      end
    end

    context 'when using native methods' do
      let(:sidekiq_worker_module) do
        Module.new do
          def self.included(base)
            base.define_singleton_method(:native_perfom_async) { |*args| args }
          end
        end
      end
      let(:worker) do
        Class.new do
          extend BackgroundJob.mixin(:sidekiq, native: true)

          def self.name
            'DummyWorker'
          end
        end
      end

      before do
        stub_const('Sidekiq', Class.new)
        stub_const('Sidekiq::Job', sidekiq_worker_module)
      end

      specify do
        expect(worker).to respond_to(:native_perfom_async)
        expect(worker.singleton_class.included_modules).not_to include(BackgroundJob::Mixin::SharedInterface)
        expect(worker).not_to respond_to(:perform_async)
        expect(worker).not_to respond_to(:perform_in)
        expect(worker).not_to respond_to(:perform_at)
      end
    end

    shared_examples 'assertions for when Sidekiq is available' do
      let(:sidekiq_worker_module) { Module.new }

      it 'includes Sidekiq::Worker or Sidekiq::Job' do
        expect(worker.included_modules).to include(sidekiq_worker_module)
        expect(worker.singleton_class.included_modules).to include(BackgroundJob::Mixin::SharedInterface)
      end

      it 'responds enqueuing methods' do
        expect(worker).to respond_to(:perform_async)
        expect(worker).to respond_to(:perform_in)
        expect(worker).to respond_to(:perform_at)
      end

      it 'returns :sidekiq as the service' do
        expect(worker.background_job_service).to eq(:sidekiq)
      end

      it 'returns the default from Sidekiq' do
        expect(worker.background_job_default_options).to eq(
          queue: 'sidekiq_global',
          retry: 0,
        )
      end

      it 'replace the :retry from configurations' do
        BackgroundJob.config.sidekiq.jobs[worker.name] = {
          retry: 10,
        }
        expect(worker.background_job_default_options).to eq(
          queue: 'sidekiq_global',
          retry: 10,
        )
      end

      it 'replace the :queue from configurations' do
        BackgroundJob.config.sidekiq.jobs[worker.name] = {
          queue: 'config',
        }
        expect(worker.background_job_default_options).to eq(
          queue: 'config',
          retry: 0,
        )
      end
    end

    context "with global Sidekiq < 7 available" do
      let(:worker) do
        Class.new do
          extend BackgroundJob.mixin(:sidekiq)

          def self.name
            'DummyWorker'
          end
        end
      end
      before do
        stub_const('Sidekiq', Class.new do
          def self.default_worker_options
            {
              'queue' => 'sidekiq_global',
              'retry' => 0,
            }
          end
        end)
        stub_const('Sidekiq::Worker', sidekiq_worker_module)
      end

      include_examples 'assertions for when Sidekiq is available'
    end

    context "with global Sidekiq >= 7 available" do
      let(:worker) do
        Class.new do
          extend BackgroundJob.mixin(:sidekiq)

          def self.name
            'DummyWorker'
          end
        end
      end

      before do
        stub_const('Sidekiq', Class.new do
          def self.default_job_options
            {
              'queue' => 'sidekiq_global',
              'retry' => 0,
            }
          end
        end)
        stub_const('Sidekiq::Job', sidekiq_worker_module)
      end

      include_examples 'assertions for when Sidekiq is available'
    end
  end
end
