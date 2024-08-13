# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackgroundJob::Configuration::Faktory do
  describe "#workers" do
    it "returns a hash" do
      expect(described_class.new.workers).to be_a(Hash)
    end

    it "normalizes the workers" do
      config = described_class.new
      config.workers = {"foo" => {"queue" => "bar"}}
      expect(config.workers["foo"]).to eq(queue: "bar")
    end

    it "overwrites the default workers options" do
      config = described_class.new
      config.workers = {"BackgroundJob::Jobs::ImportBatchIdJob" => {"queue" => "bar"}}
      expect(config.workers["BackgroundJob::Jobs::ImportBatchIdJob"]).to eq(queue: "bar")
    end
  end
end
