# frozen_string_literal: true

require "rails_helper"

RSpec.describe Metadata::UpdateItemService do
  subject(:service) { described_class.new(owner:, value:, partial:) }

  let(:organization) { create(:organization) }
  let(:owner) { create(:credit_note, organization:) }
  let(:value) { nil }
  let(:partial) { false }

  describe "#call" do
    context "when owner does not support metadata" do
      let(:owner) { create(:organization) }

      it "raises an exception" do
        expect { service.call }.to raise_exception(NoMethodError)
      end
    end

    context "with value: nil, partial: true, no existing metadata" do
      let(:value) { nil }
      let(:partial) { true }

      it "does not create metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be false
        expect(owner.reload.metadata).to be_nil
      end
    end

    context "with value: nil, partial: true, existing metadata" do
      let(:value) { nil }
      let(:partial) { true }

      before { create(:item_metadata, owner:, organization:, value: {"foo" => "bar"}) }

      it "preserves existing metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be false
        expect(owner.reload.metadata.value).to eq({"foo" => "bar"})
      end
    end

    context "with value: nil, partial: false, no existing metadata" do
      let(:value) { nil }
      let(:partial) { false }

      it "does not create metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be false
        expect(owner.reload.metadata).to be_nil
      end
    end

    context "with value: nil, partial: false, existing metadata" do
      let(:value) { nil }
      let(:partial) { false }
      let!(:existing_metadata) { create(:item_metadata, owner:, organization:, value: {"foo" => "bar"}) }

      it "deletes existing metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be true
        expect(owner.reload.metadata).to be_nil
        expect(Metadata::ItemMetadata.find_by(id: existing_metadata.id)).to be_nil
      end
    end

    context "with value: {}, partial: true, no existing metadata" do
      let(:value) { {} }
      let(:partial) { true }

      it "does not create metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be false
        expect(owner.reload.metadata).to be_nil
      end
    end

    context "with value: {}, partial: true, existing metadata" do
      let(:value) { {} }
      let(:partial) { true }

      before { create(:item_metadata, owner:, organization:, value: {"foo" => "bar"}) }

      it "preserves existing metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be false
        expect(owner.reload.metadata.value).to eq({"foo" => "bar"})
      end
    end

    context "with value: {}, partial: false, no existing metadata" do
      let(:value) { {} }
      let(:partial) { false }

      it "creates metadata with empty hash" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be true
        expect(owner.reload.metadata.value).to eq({})
      end
    end

    context "with value: {}, partial: false, existing metadata" do
      let(:value) { {} }
      let(:partial) { false }

      before { create(:item_metadata, owner:, organization:, value: {"foo" => "bar"}) }

      it "replaces with empty hash" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be true
        expect(owner.reload.metadata.value).to eq({})
      end
    end

    context "with value: {foo: bar, baz: qux}, partial: true, no existing metadata" do
      let(:value) { {"foo" => "bar", "baz" => "qux"} }
      let(:partial) { true }

      it "creates metadata" do
        result = service.call
        expect(result).to be_success
        expect(result.metadata_changed).to be true

        metadata = owner.reload.metadata
        expect(metadata.value).to eq({"foo" => "bar", "baz" => "qux"})
        expect(metadata.organization_id).to eq(organization.id)
        expect(metadata.owner).to eq(owner)
      end
    end

    context "with value: {foo: bar, baz: qux}, partial: true, existing metadata" do
      let(:value) { {"foo" => "bar", "baz" => "qux"} }
      let(:partial) { true }

      before { create(:item_metadata, owner:, organization:, value: {"old" => "value"}) }

      it "merges metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be true
        expect(owner.reload.metadata.value).to eq({"old" => "value", "foo" => "bar", "baz" => "qux"})
      end
    end

    context "with value: {foo: bar}, partial: false, no existing metadata" do
      let(:value) { {"foo" => "bar"} }
      let(:partial) { false }

      it "creates metadata" do
        expect { service.call }.to change(Metadata::ItemMetadata, :count).by(1)
        expect(owner.reload.metadata.value).to eq({"foo" => "bar"})
      end
    end

    context "with value: {foo: bar}, partial: false, existing metadata" do
      let(:value) { {"foo" => "bar"} }
      let(:partial) { false }

      before { create(:item_metadata, owner:, organization:, value: {"old" => "value"}) }

      it "replaces metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be true
        expect(owner.reload.metadata.value).to eq({"foo" => "bar"})
      end
    end

    context "with metadata overwriting existing key" do
      let(:value) { {"foo" => "new"} }
      let(:partial) { true }

      before { create(:item_metadata, owner:, organization:, value: {"foo" => "old"}) }

      it "overwrites the key" do
        result = service.call

        expect(result).to be_success
        expect(owner.reload.metadata.value).to eq({"foo" => "new"})
      end
    end

    context "with value: {foo: nil}, no existing metadata" do
      let(:value) { {"foo" => nil} }
      let(:partial) { true }

      it "creates metadata with nil value" do
        result = service.call

        expect(result).to be_success
        expect(owner.reload.metadata.value).to eq({"foo" => nil})
      end
    end

    context "with value: {foo: nil}, existing metadata" do
      let(:value) { {"foo" => nil} }
      let(:partial) { true }

      before { create(:item_metadata, owner:, organization:, value: {"foo" => "bar"}) }

      it "sets key to nil" do
        result = service.call

        expect(result).to be_success
        expect(owner.reload.metadata.value).to eq({"foo" => nil})
      end
    end

    context "with value: {foo: ''}, no existing metadata" do
      let(:value) { {"foo" => ""} }
      let(:partial) { true }

      it "creates metadata with empty string" do
        result = service.call

        expect(result).to be_success
        expect(owner.reload.metadata.value).to eq({"foo" => ""})
      end
    end

    context "with value: {foo: ''}, existing metadata" do
      let(:value) { {"foo" => ""} }
      let(:partial) { true }

      before { create(:item_metadata, owner:, organization:, value: {"foo" => "old", "bar" => "keep"}) }

      it "merges with empty string" do
        result = service.call

        expect(result).to be_success
        expect(owner.reload.metadata.value).to eq({"foo" => "", "bar" => "keep"})
      end
    end

    context "when replacing with same value" do
      let(:value) { {"foo" => "bar"} }
      let(:partial) { false }

      before { create(:item_metadata, owner:, organization:, value: {"foo" => "bar"}) }

      it "does not change metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be false
        expect(owner.reload.metadata.value).to eq({"foo" => "bar"})
      end
    end

    context "when merging with same value" do
      let(:value) { {"foo" => "bar"} }
      let(:partial) { true }

      before { create(:item_metadata, owner:, organization:, value: {"foo" => "bar"}) }

      it "does not change metadata" do
        result = service.call

        expect(result).to be_success
        expect(result.metadata_changed).to be false
        expect(owner.reload.metadata.value).to eq({"foo" => "bar"})
      end
    end
  end
end
