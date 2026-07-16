# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorDetail do
  it { is_expected.to belong_to(:owner) }
  it { is_expected.to belong_to(:organization) }

  context "when creating an invoice generation error for an invoice" do
    let(:invoice) { create(:invoice, :generating) }
    let(:result) { BaseService::Result.new }
    let(:error) { BaseService::ValidationFailure.new(result, messages: messages) }
    let(:messages) { ["message1", "message2"] }

    let(:error_with_backtrace) do
      error = OpenStruct.new
      error.backtrace = "backtrace"
      error
    end

    describe ".create_generation_error_for" do
      it "does nothing if the invoice is nil" do
        expect(described_class.create_generation_error_for(invoice: nil, error:)).to eq(nil)
      end

      it "creates an error detail with link to invoice as an owner" do
        invoice_error = described_class.create_generation_error_for(invoice:, error:)
        expect(invoice_error.owner).to eq(invoice)
      end

      it "stores the error in the details: :error field" do
        invoice_error = described_class.create_generation_error_for(invoice:, error:)
        expect(invoice_error.details["error"]).to eq(error.inspect.to_json)
      end

      it "stores the backtrace in the details: :backtrace field" do
        invoice_error = described_class.create_generation_error_for(invoice:, error: error_with_backtrace)
        expect(invoice_error.details["backtrace"]).to eq("backtrace")
      end

      it "stores the subscriptions in the details: :subscriptions field" do
        invoice_error = described_class.create_generation_error_for(invoice:, error:)
        expect(invoice_error.details["subscriptions"]).to eq("[]")
      end

      it "updates when create_for is called with the same invoice" do
        invoice_error = described_class.create_generation_error_for(invoice:, error:)
        id = invoice_error.id

        invoice_error = described_class.create_generation_error_for(invoice:, error:)
        expect(invoice_error.id).to eq(id)
      end
    end
  end
end
