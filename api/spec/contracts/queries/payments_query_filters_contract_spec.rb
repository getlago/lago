# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::PaymentsQueryFiltersContract do
  subject(:result) { described_class.new.call(filters.to_h) }

  let(:filters) { {} }

  context "when filters are valid" do
    context "when invoice_id is valid" do
      let(:filters) { {invoice_id: "7b199d93-2663-4e68-beca-203aefcd019b"} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when invoice_id is blank" do
      let(:filters) { {invoice_id: nil} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when external_customer_id is valid" do
      let(:filters) { {external_customer_id: "valid_string"} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when external_customer_id is blank" do
      let(:filters) { {external_customer_id: nil} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when both invoice_id and external_customer_id are valid" do
      let(:filters) { {invoice_id: "7b199d93-2663-4e68-beca-203aefcd019b", external_customer_id: "valid_string"} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end
  end

  context "when filters are invalid" do
    context "when invoice_id is not a UUID" do
      let(:filters) { {invoice_id: "invalid_uuid"} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include(invoice_id: ["is in invalid format"])
      end
    end

    context "when external_customer_id is not a string" do
      let(:filters) { {external_customer_id: 123} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include(external_customer_id: ["must be a string"])
      end
    end

    context "when both invoice_id and external_customer_id are invalid" do
      let(:filters) { {invoice_id: "invalid_uuid", external_customer_id: 123} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include(
          invoice_id: ["is in invalid format"],
          external_customer_id: ["must be a string"]
        )
      end
    end
  end
end
