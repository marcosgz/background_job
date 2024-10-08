# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BackgroundJob::Jobs::Job do
  let(:worker) { described_class.new('DummyWorker') }

  describe '#options' do
    specify do
      expected_options = described_class.new('DummyWorker').options
      expect(expected_options).to eq({})
    end

    specify do
      expected_options = described_class.new('DummyWorker', retry: true).options
      expect(expected_options).to eq(retry: true)
    end
  end

  describe '#created_at', freeze_at: [2020, 7, 1, 22, 24, 40] do
    let(:now) { Time.now }

    specify do
      expect(worker.payload).to eq({})
      expect(worker.created_at(now)).to eq(worker)
      expect(worker.payload).to eq('created_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.created_at(Time.now)).to eq(worker)
      expect(worker.payload).to eq('created_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.created_at(Time.now.to_datetime.rfc3339(9))).to eq(worker)
      expect(worker.payload).to eq('created_at' => now.to_f)
    end
  end

  describe '#enqueued_at', freeze_at: [2020, 7, 1, 22, 24, 40] do
    let(:now) { Time.now }

    specify do
      expect(worker.payload).to eq({})
      expect(worker.enqueued_at(now)).to eq(worker)
      expect(worker.payload).to eq('enqueued_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.enqueued_at(Time.now)).to eq(worker)
      expect(worker.payload).to eq('enqueued_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.enqueued_at(Time.now.to_datetime.rfc3339(9))).to eq(worker)
      expect(worker.payload).to eq('enqueued_at' => now.to_f)
    end
  end

  describe '#with_args' do
    specify do
      expect(worker.payload).to eq({})
      expect(worker.with_args()).to eq(worker)
      expect(worker.payload).to eq('args' => [])
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.with_args(1)).to eq(worker)
      expect(worker.payload).to eq('args' => [1])
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.with_args(1, foo: :bar)).to eq(worker)
      expect(worker.payload).to eq('args' => [1, { foo: :bar }])
    end
  end

  describe '#at', freeze_at: [2020, 7, 1, 22, 24, 40] do
    let(:now) { Time.now }

    specify do
      expect(worker.payload).to eq({})
      expect(worker.at(10)).to eq(worker)
      expect(worker.payload).to eq('at' => now.to_f + 10, 'created_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.at(now + HOUR_IN_SECONDS)).to eq(worker)
      expect(worker.payload).to eq('at' => now.to_f + 3_600, 'created_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.at((now + HOUR_IN_SECONDS).to_datetime.rfc3339(9))).to eq(worker)
      expect(worker.payload).to eq('at' => now.to_f + 3_600, 'created_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.at(0)).to eq(worker)
      expect(worker.payload).to eq({})
      expect(worker.at(now - 1)).to eq(worker)
      expect(worker.payload).to eq({})
    end
  end

  describe '#in', freeze_at: [2020, 7, 1, 22, 24, 40] do
    let(:now) { Time.now }

    specify do
      expect(worker.payload).to eq({})
      expect(worker.in(10)).to eq(worker)
      expect(worker.payload).to eq('at' => now.to_f + 10, 'created_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.in(now + HOUR_IN_SECONDS)).to eq(worker)
      expect(worker.payload).to eq('at' => now.to_f + 3_600, 'created_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.in((now + HOUR_IN_SECONDS).to_datetime.rfc3339(9))).to eq(worker)
      expect(worker.payload).to eq('at' => now.to_f + 3_600, 'created_at' => now.to_f)
    end

    specify do
      expect(worker.payload).to eq({})
      expect(worker.in(0)).to eq(worker)
      expect(worker.payload).to eq({})
      expect(worker.in(now - 1)).to eq(worker)
      expect(worker.payload).to eq({})
    end
  end

  describe '#unique' do
    specify do
      worker = described_class.new('DummyWorker')
      expect(worker.unique_job).to eq(nil)
      expect(worker.unique(true)).to eq(worker)
      expect(worker).to be_unique_job
      expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
      expect(worker.unique(false)).to eq(worker)
      expect(worker.unique_job).to eq(nil)
      expect(worker).not_to be_unique_job
    end

    specify do
      worker = described_class.new('DummyWorker')
      expect(worker.unique_job).to eq(nil)
      expect(worker.unique(across: :systemwide)).to eq(worker)
      expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
      expect(worker).to be_unique_job
    end

    specify do
      worker = described_class.new('DummyWorker')
      expect(worker.unique_job).to eq(nil)
      unique_job = BackgroundJob::UniqueJob.new
      expect(worker.unique(unique_job)).to eq(worker)
      expect(worker.unique_job).to eq(unique_job)
      expect(worker).to be_unique_job
    end
  end

  describe '#unique_job' do
    let(:defaults) do
      {
        across: :queue,
        timeout: WEEK_IN_SECONDS,
        unlock_policy: :success,
      }
    end

    specify do
      worker = described_class.new('DummyWorker')
      expect(worker.payload).to eq({})
      expect(worker.options).to eq({})
      expect(worker.unique_job).to eq(nil)
    end

    specify do
      worker = described_class.new('DummyWorker', uniq: {})
      expect(worker.payload).to eq({})
      expect(worker.options).to eq({})
      expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
    end

    specify do
      worker = described_class.new('DummyWorker', uniq: true)
      expect(worker.payload).to eq({})
      expect(worker.options).to eq({})
      expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
    end

    specify do
      worker = described_class.new('DummyWorker', uniq: false)
      expect(worker.payload).to eq({})
      expect(worker.options).to eq({})
      expect(worker.unique_job).to eq(nil)
    end

    context 'with custom :across option' do
      specify do
        expect { described_class.new('DummyWorker', uniq: { across: :invalid }) }.to raise_error(
          BackgroundJob::Error, 'Invalid `across: :invalid` option. Only [:queue, :systemwide] are allowed.'
        )
      end

      specify do
        worker = described_class.new('DummyWorker', uniq: { across: :queue })
        expect(worker.options).to eq({})
        expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
        expect(worker.unique_job.across).to eq(:queue)
      end

      specify do
        worker = described_class.new('DummyWorker', uniq: { across: :systemwide })
        expect(worker.payload).to eq({})
        expect(worker.options).to eq({})
        expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
        expect(worker.unique_job.across).to eq(:systemwide)
      end

      specify do
        worker = described_class.new('DummyWorker', uniq: { across: 'systemwide' })
        expect(worker.payload).to eq({})
        expect(worker.options).to eq({})
        expect(worker.unique_job.across).to eq(:systemwide)
      end
    end

    context 'with custom :unlock_policy option' do
      specify do
        expect { described_class.new('DummyWorker', uniq: { unlock_policy: :invalid }) }.to raise_error(
          BackgroundJob::Error, 'Invalid `unlock_policy: :invalid` option. Only [:success, :start] are allowed.'
        )
      end

      specify do
        worker = described_class.new('DummyWorker', uniq: { unlock_policy: :success })
        expect(worker.payload).to eq({})
        expect(worker.options).to eq({})
        expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
        expect(worker.unique_job.unlock_policy).to eq(:success)
      end

      specify do
        worker = described_class.new('DummyWorker', uniq: { unlock_policy: :start })
        expect(worker.payload).to eq({})
        expect(worker.options).to eq({})
        expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
        expect(worker.unique_job.unlock_policy).to eq(:start)
      end

      specify do
        worker = described_class.new('DummyWorker', uniq: { unlock_policy: 'start' })
        expect(worker.payload).to eq({})
        expect(worker.options).to eq({})
        expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
        expect(worker.unique_job.unlock_policy).to eq(:start)
      end
    end

    context 'with custom :timeout option' do
      specify do
        worker = described_class.new('DummyWorker', uniq: { timeout: -1 })
        expect(worker.payload).to eq({})
        expect(worker.options).to eq({})
        expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
        expect(worker.unique_job.timeout).to eq(defaults[:timeout])
      end

      specify do
        worker = described_class.new('DummyWorker', uniq: { timeout: 10 })
        expect(worker.payload).to eq({})
        expect(worker.options).to eq({})
        expect(worker.unique_job).to be_an_instance_of(BackgroundJob::UniqueJob)
        expect(worker.unique_job.timeout).to eq(10)
      end
    end
  end

  describe '#eql?' do
    context 'worker class name' do
      specify do
        expect(described_class.new('Foo')).to eql(described_class.new('Foo'))
        expect(described_class.new('Foo')).to eq(described_class.new('Foo'))
      end

      specify do
        expect(described_class.new('Bar')).not_to eql(described_class.new('Foo'))
        expect(described_class.new('Bar')).not_to eq(described_class.new('Foo'))
      end
    end

    context 'job content' do
      specify do
        expect(described_class.new('Foo').with_args([1])).to eql(described_class.new('Foo').with_args([1]))
        expect(described_class.new('Foo').with_args([1])).to eq(described_class.new('Foo').with_args([1]))
      end

      specify do
        expect(described_class.new('Foo').with_args([1])).not_to eql(described_class.new('Foo').with_args([2]))
        expect(described_class.new('Foo').with_args([1])).not_to eq(described_class.new('Foo').with_args([2]))
      end
    end

    context 'worker options' do
      specify do
        expect(described_class.new('Foo', queue: 'foo')).to eql(described_class.new('Foo', queue: 'foo'))
        expect(described_class.new('Foo', queue: 'foo')).to eq(described_class.new('Foo', queue: 'foo'))
      end

      specify do
        expect(described_class.new('Foo', queue: 'foo')).not_to eql(described_class.new('Foo', queue: 'bar'))
        expect(described_class.new('Foo', queue: 'foo')).not_to eq(described_class.new('Foo', queue: 'bar'))
      end
    end
  end

  describe '#to_s' do
    specify do
      expect(described_class.new('Foo').to_s).to match(/#<BackgroundJob::Jobs::Job:0x\h+ job_class="Foo">/)
    end

    specify do
      expect(described_class.new('Foo', queue: 'bar').to_s).to match(
        /#<BackgroundJob::Jobs::Job:0x\h+ job_class="Foo",.*options=.*queue.*>/
      )
    end

    specify do
      expect(described_class.new('Foo', queue: 'bar', retry: true).to_s).to match(
        /#<BackgroundJob::Jobs::Job:0x\h+ job_class="Foo",.*options=.*queue.*retry.*>/
      )
    end

    specify do
      expect(described_class.new('Foo').with_args(1).to_s).to match(
        /#<BackgroundJob::Jobs::Job:0x\h+ job_class="Foo", args=\[1\]>/
      )
    end
  end
end
