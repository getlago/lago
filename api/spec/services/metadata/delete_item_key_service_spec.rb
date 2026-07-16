# frozen_string_literal: true

require "rails_helper"

RSpec.describe Metadata::DeleteItemKeyService do
  subject(:service) { described_class.new(item:, key:) }

  let(:organization) { create(:organization) }
  let(:owner) { create(:credit_note, organization:) }
  let(:item) { create(:item_metadata, owner:, organization:, value:) }
  let(:value) { {"foo" => "bar", "baz" => "qux"} }
  let(:key) { "foo" }

  describe "#call" do
    context "when key exists" do
      it "removes the key from metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be(true)
        expect(item.reload.value).to eq({"baz" => "qux"})
      end
    end

    context "when key does not exist" do
      let(:key) { "nonexistent" }

      it "does not modify metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be(false)
        expect(item.reload.value).to eq({"foo" => "bar", "baz" => "qux"})
      end
    end

    context "when key is a symbol" do
      let(:key) { :foo }

      it "converts key to string and removes it" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be(true)
        expect(item.reload.value).to eq({"baz" => "qux"})
      end
    end

    context "when removing the last key" do
      let(:value) { {"foo" => "bar"} }

      it "leaves empty hash" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be(true)
        expect(item.reload.value).to eq({})
      end
    end

    context "when value contains nil" do
      let(:value) { {"foo" => nil, "baz" => "qux"} }

      it "removes key with nil value" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be(true)
        expect(item.reload.value).to eq({"baz" => "qux"})
      end
    end

    context "when value contains empty string" do
      let(:value) { {"foo" => "", "baz" => "qux"} }

      it "removes key with empty string" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be(true)
        expect(item.reload.value).to eq({"baz" => "qux"})
      end
    end
  end
end
