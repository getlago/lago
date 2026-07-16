# frozen_string_literal: true

require "rails_helper"

RSpec.describe Metadata::InvoiceMetadata do
  subject(:metadata) { described_class.new(attributes) }

  let(:invoice) { create(:invoice) }
  let(:key) { "hello" }
  let(:value) { "abcdef" }
  let(:attributes) do
    {key:, value:, invoice:, organization: invoice.organization}
  end

  describe "associations" do
    it do
      expect(subject).to belong_to(:invoice).touch(true)
      expect(subject).to belong_to(:organization)
    end
  end

  describe "validations" do
    context "when uniqueness condition is satisfied" do
      it { expect(metadata).to be_valid }
    end

    context "when key is not unique" do
      let(:old_metadata) { create(:invoice_metadata, invoice:, key: "hello") }

      before { old_metadata }

      it { expect(metadata).not_to be_valid }
    end

    context "when key length is invalid" do
      let(:key) { "hello-hello-hello-hello-hello" }

      it { expect(metadata).not_to be_valid }
    end
  end
end
