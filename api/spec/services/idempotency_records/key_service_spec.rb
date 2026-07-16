# frozen_string_literal: true

require "rails_helper"

RSpec.describe IdempotencyRecords::KeyService do
  subject(:result) { described_class.call(**key_parts) }

  let(:key_parts) { {} }

  describe "#call" do
    it "returns the same value when called twice" do
      expect(result.idempotency_key).to eq(described_class.call(*key_parts).idempotency_key)
    end

    context "with one key_part" do
      let(:key_parts) { {"key" => "value"} }

      it "returns the same value when called twice" do
        expect(result.idempotency_key).to eq(described_class.call(**key_parts).idempotency_key)
      end

      it "returns a different value if the value is different" do
        key_parts2 = {"key" => "value2"}
        expect(result.idempotency_key).not_to eq(described_class.call(**key_parts2).idempotency_key)
      end
    end

    context "with multiple key_parts" do
      let(:key_parts) { {k1: "key1", k2: "key2"} }
      let(:key_parts_reversed) { {k2: "key2", k1: "key1"} }

      it "returns the same value when called twice" do
        expect(result.idempotency_key).to eq(described_class.call(**key_parts).idempotency_key)
      end

      it "returns the same value if the order of the key_parts changes" do
        expect(result.idempotency_key).to eq(described_class.call(**key_parts_reversed).idempotency_key)
      end
    end

    context "when key_parts overlap in content" do
      let(:key_parts) { {key1: "k", key2: "ey"} }
      let(:key_parts_overlap) { {key1: "ke", key2: "y"} }

      it "does not return the same value" do
        expect(result.idempotency_key).not_to eq(described_class.call(**key_parts_overlap).idempotency_key)
      end
    end
  end
end
