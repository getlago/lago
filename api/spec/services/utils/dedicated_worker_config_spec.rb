# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::DedicatedWorkerConfig do
  describe ".organization_ids" do
    context "when the constant is empty" do
      before { stub_const("#{described_class}::ORGANIZATION_IDS", []) }

      it "returns an empty array" do
        expect(described_class.organization_ids).to eq([])
      end
    end

    context "when the constant has ids" do
      before { stub_const("#{described_class}::ORGANIZATION_IDS", %w[abc def ghi]) }

      it "returns the ids" do
        expect(described_class.organization_ids).to eq(%w[abc def ghi])
      end
    end
  end

  describe ".enabled_for?" do
    before { stub_const("#{described_class}::ORGANIZATION_IDS", %w[org-1 org-2]) }

    it "returns false for nil" do
      expect(described_class.enabled_for?(nil)).to be(false)
    end

    it "returns false for blank string" do
      expect(described_class.enabled_for?("")).to be(false)
    end

    it "returns true for a listed id" do
      expect(described_class.enabled_for?("org-1")).to be(true)
    end

    it "returns false for an unlisted id" do
      expect(described_class.enabled_for?("org-3")).to be(false)
    end
  end

  describe ".refresh_interval" do
    around do |example|
      previous = ENV["LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS"]
      example.run
    ensure
      ENV["LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS"] = previous
    end

    context "when the env var is a positive integer" do
      before { ENV["LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS"] = "10" }

      it "returns the configured value" do
        expect(described_class.refresh_interval).to eq(10)
      end
    end

    context "when the env var is not a positive integer" do
      [nil, "", "0", "-3"].each do |value|
        it "returns the default value of 5 when set to #{value.inspect}" do
          if value.nil?
            ENV.delete("LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS")
          else
            ENV["LAGO_DEDICATED_REFRESH_INTERVAL_SECONDS"] = value
          end

          expect(described_class.refresh_interval).to eq(5)
        end
      end
    end
  end

  describe ".any?" do
    context "when the constant is empty" do
      before { stub_const("#{described_class}::ORGANIZATION_IDS", []) }

      it "returns false" do
        expect(described_class.any?).to be(false)
      end
    end

    context "when the constant has ids" do
      before { stub_const("#{described_class}::ORGANIZATION_IDS", %w[org-1]) }

      it "returns true" do
        expect(described_class.any?).to be(true)
      end
    end
  end
end
