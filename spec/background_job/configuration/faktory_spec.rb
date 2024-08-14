# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackgroundJob::Configuration::Faktory do
  describe "#jobs" do
    it "returns a hash" do
      expect(described_class.new.jobs).to be_a(Hash)
    end

    it "normalizes the jobs" do
      config = described_class.new
      config.jobs = {"foo" => {"queue" => "bar"}}
      expect(config.jobs["foo"]).to eq(queue: "bar")
    end

    it "overwrites the default jobs options" do
      config = described_class.new
      config.jobs = {"BackgroundJob::Jobs::ImportBatchIdJob" => {"queue" => "bar"}}
      expect(config.jobs["BackgroundJob::Jobs::ImportBatchIdJob"]).to eq(queue: "bar")
    end
  end
end
