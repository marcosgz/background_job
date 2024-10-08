# frozen_string_literal: true

require 'spec_helper'
require 'background_job/mixin/faktory'

RSpec.describe BackgroundJob::Mixin::Faktory do
  after do
    reset_config!
  end

  describe '.background_job_service' do
    let(:worker) do
      Class.new do
        extend BackgroundJob.mixin(:faktory)
      end
    end

    specify do
      expect(worker.background_job_service).to eq(:faktory)
    end
  end

  describe '.background_job_options' do
    let(:faktory_job_module) { Module.new }
    let(:job_name) { 'Noop' }

    before do
      stub_const('Faktory', Class.new do
        def self.default_job_options
          {
            'queue' => 'faktory_global',
            'retry' => 0,
          }
        end
      end)
    end

    after do
      reset_config!
    end

    specify do
      expect(described_class.background_job_options(job_name)).to eq(
        queue: 'faktory_global',
        retry: 0,
      )
    end

    it 'replaces the :queue from configurations' do
      BackgroundJob.config.faktory.jobs[job_name] = {
        queue: 'config',
      }
      expect(described_class.background_job_options(job_name)).to eq(
        queue: 'config',
        retry: 0,
      )
    end

    it 'replace the :retry from configurations' do
      BackgroundJob.config.faktory.jobs[job_name] = {
        retry: 10,
      }
      expect(described_class.background_job_options(job_name)).to eq(
        queue: 'faktory_global',
        retry: 10,
      )
    end
  end

  describe 'BackgroundJob#mixin' do
    context 'with default settings' do
      let(:worker) do
        Class.new do
          extend BackgroundJob.mixin(:faktory)

          def self.name
            'DummyWorker'
          end
        end
      end

      specify do
        expect(worker).to respond_to(:perform_async)
        expect(worker).to respond_to(:perform_in)
        expect(worker).to respond_to(:perform_at)
      end

      specify do
        expect(worker.background_job_default_options).to eq(
          queue: 'default',
          retry: 25,
        )
      end

      specify do
        expect(worker.background_job_user_options).to be_a_kind_of(Hash)
      end
    end

    context 'with global Faktory available' do
      let(:faktory_job_module) { Module.new }

      before do
        stub_const('Faktory', Class.new do
          def self.default_job_options
            {
              'queue' => 'faktory_global',
              'retry' => 0,
            }
          end
        end)
        stub_const('Faktory::Job', faktory_job_module)
      end

      let(:worker) do
        Class.new do
          extend BackgroundJob.mixin(:faktory)

          def self.name
            'DummyWorker'
          end
        end
      end

      it 'includes Sidekiq::Job' do
        expect(worker.included_modules).to include(faktory_job_module)
        expect(worker.singleton_class.included_modules).to include(BackgroundJob::Mixin::SharedInterface)
      end

      specify do
        expect(worker).to respond_to(:perform_async)
        expect(worker).to respond_to(:perform_in)
        expect(worker).to respond_to(:perform_at)
      end

      it 'returns :faktory as the service' do
        expect(worker.background_job_service).to eq(:faktory)
      end

      specify do
        expect(worker.background_job_default_options).to eq(
          queue: 'faktory_global',
          retry: 0,
        )
      end

      it 'replaces the :queue from configurations' do
        BackgroundJob.config.faktory.jobs[worker.name] = {
          queue: 'config',
        }
        expect(worker.background_job_default_options).to eq(
          queue: 'config',
          retry: 0,
        )
      end

      it 'replace the :retry from configurations' do
        BackgroundJob.config.faktory.jobs[worker.name] = {
          retry: 10,
        }
        expect(worker.background_job_default_options).to eq(
          queue: 'faktory_global',
          retry: 10,
        )
      end
    end

    context 'with custom settings' do
      let(:worker1) do
        Class.new do
          extend BackgroundJob.mixin(:faktory, queue: 'one', retry: 1)

          def self.name
            'DummyWorkerOne'
          end
        end
      end

      let(:worker2) do
        Class.new do
          extend BackgroundJob.mixin(:faktory, queue: 'two', retry: 2)

          def self.name
            'DummyWorkerTwo'
          end
        end
      end

      after do
        reset_config!
      end

      it 'responds to the enqueuing methods' do
        expect(worker1).to respond_to(:perform_async)
        expect(worker2).to respond_to(:perform_async)
        expect(worker1).to respond_to(:perform_in)
        expect(worker2).to respond_to(:perform_in)
        expect(worker1).to respond_to(:perform_at)
        expect(worker1).to respond_to(:perform_at)
      end

      it 'returns the user given options' do
        expect(worker1.background_job_user_options).to eq({
          queue: 'one',
          retry: 1,
        })
        expect(worker2.background_job_user_options).to eq({
          queue: 'two',
          retry: 2,
        })
      end
    end

    context 'when using native methods' do
      let(:faktory_job_module) do
        Module.new do
          def self.included(base)
            base.define_singleton_method(:native_perfom_async) { |*args| args }
          end
        end
      end

      before do
        stub_const('Faktory', Class.new)
        stub_const('Faktory::Job', faktory_job_module)
      end

      let(:worker) do
        Class.new do
          extend BackgroundJob.mixin(:faktory, native: true)

          def self.name
            'DummyWorker'
          end
        end
      end

      specify do
        expect(worker).to respond_to(:native_perfom_async)
        expect(worker.singleton_class.included_modules).not_to include(BackgroundJob::Mixin::SharedInterface)
        expect(worker).not_to respond_to(:perform_async)
        expect(worker).not_to respond_to(:perform_in)
        expect(worker).not_to respond_to(:perform_at)
      end
    end
  end
end
