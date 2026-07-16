# frozen_string_literal: true

require "rails_helper"

RSpec.describe Validators::MetadataValidator do
  subject(:metadata_validator) { described_class.new(metadata) }

  let(:max_keys) { Validators::MetadataValidator::DEFAULT_CONFIG[:max_keys] }
  let(:max_key_length) { Validators::MetadataValidator::DEFAULT_CONFIG[:max_key_length] }
  let(:max_value_length) { Validators::MetadataValidator::DEFAULT_CONFIG[:max_value_length] }

  describe ".valid?" do
    let(:metadata) { [{"key" => "valid_key", "value" => "valid_value"}] }

    it "returns true for valid metadata" do
      expect(metadata_validator).to be_valid
    end

    context "when metadata has too many key-value pairs" do
      let(:metadata) { (1..max_keys + 1).map { |i| {"key" => "key#{i}", "value" => "value#{i}"} } }

      it "returns false" do
        expect(metadata_validator).not_to be_valid
        expect(metadata_validator.errors[:metadata]).to include("too_many_keys")
      end
    end

    context "when metadata contains a key that is too long" do
      let(:metadata) { [{"key" => "a" * (max_key_length + 1), "value" => "valid"}] }

      it "returns false" do
        expect(metadata_validator).not_to be_valid
        expect(metadata_validator.errors[:metadata]).to include("key_too_long")
      end
    end

    context "when metadata contains a value that is too long" do
      let(:metadata) { [{"key" => "key", "value" => "a" * (max_value_length + 1)}] }

      it "returns false" do
        expect(metadata_validator).not_to be_valid
        expect(metadata_validator.errors[:metadata]).to include("value_too_long")
      end
    end

    context "when metadata contains nested structures as value" do
      let(:metadata) { [{"key" => "key", "value" => {"key" => "nested_value"}}] }

      it "returns false" do
        expect(metadata_validator).not_to be_valid
        expect(metadata_validator.errors[:metadata]).to include("nested_structure_not_allowed")
      end
    end

    context "when metadata is a single hash instead of an array" do
      let(:metadata) { {"key" => "fixed", "value" => "0"} }

      it "returns false" do
        expect(metadata_validator).not_to be_valid
        expect(metadata_validator.errors[:metadata]).to include("invalid_key_value_pair")
      end
    end

    context "when metadata contains a hash with invalid key-value pair structure" do
      let(:metadata) { [{"key1" => "value1", "key2" => "value2"}] }

      it "returns false" do
        expect(metadata_validator).not_to be_valid
        expect(metadata_validator.errors[:metadata]).to include("invalid_key_value_pair")
      end
    end

    context "when metadata is empty" do
      let(:metadata) {}

      it "returns true" do
        expect(metadata_validator).to be_valid
      end
    end

    context "when metadata is an empty array" do
      let(:metadata) { [] }

      it "returns true" do
        expect(metadata_validator).to be_valid
      end
    end

    context "when metadata is an empty hash" do
      let(:metadata) { {} }

      it "returns false" do
        expect(metadata_validator).not_to be_valid
        expect(metadata_validator.errors[:metadata]).to include("invalid_type")
      end
    end
  end
end
