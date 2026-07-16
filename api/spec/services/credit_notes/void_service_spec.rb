# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::VoidService do
  subject(:void_service) { described_class.new(credit_note:) }

  let(:credit_note) { create(:credit_note) }

  describe "#call" do
    it "voids the credit_note" do
      result = void_service.call

      expect(result).to be_success

      expect(result.credit_note).to be_voided
      expect(result.credit_note.voided_at).to be_present
      expect(result.credit_note.balance_amount_cents).to eq(0)
    end

    context "when credit note is nil" do
      let(:credit_note) { nil }

      it "returns a failure" do
        result = void_service.call

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("credit_note")
      end
    end

    context "when credit note is draft" do
      let(:credit_note) { create(:credit_note, :draft) }

      it "returns a failure" do
        result = void_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("credit_note")
      end
    end

    context "when the credit note is not voidable" do
      let(:credit_note) { create(:credit_note, credit_status: :voided) }

      it "returns a failure" do
        result = void_service.call

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("no_voidable_amount")
      end
    end
  end
end
