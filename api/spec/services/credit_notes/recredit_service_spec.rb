# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::RecreditService do
  subject(:service) { described_class.new(credit:) }

  let(:credit_note) { credit.credit_note }

  context "when credit note is nil" do
    let(:credit) { create(:credit) }

    it "returns a failure" do
      result = service.call

      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::NotFoundFailure)
      expect(result.error.message).to eq("credit_note_not_found")
    end
  end

  context "when credit note is voided" do
    let(:credit) { create(:credit_note_credit) }

    before do
      credit_note.update! credit_status: :voided
    end

    it "returns a failure" do
      result = service.call

      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
      expect(result.error.code).to eq("credit_note_voided")
    end
  end

  context "when credit note can be recredited" do
    let(:credit) { create(:credit_note_credit) }
    let(:amount_cents) { credit_note.balance_amount_cents }
    let(:amount_cents_recredited) { credit_note.balance_amount_cents + credit.amount_cents }

    before do
      credit_note.update! credit_status: :consumed
    end

    it "recredits the credit note" do
      expect { service.call }
        .to change { credit_note.reload.balance_amount_cents }
        .from(amount_cents).to(amount_cents_recredited)

      expect(service.call).to be_success
    end

    it "updates credit note credit status to available" do
      expect { service.call }.to change { credit_note.reload.credit_status }.from("consumed").to("available")
    end
  end
end
