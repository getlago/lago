# frozen_string_literal: true

require "rails_helper"

describe CreditNotes::RecreditJob do
  subject(:perform_job) { described_class.perform_now(credit) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:source_invoice) { create(:invoice, organization:, customer:) }
  let(:credit_note) do
    create(:credit_note, organization:, customer:, invoice: source_invoice, credit_status: :available)
  end
  let(:credit) { create(:credit_note_credit, organization:, invoice:, credit_note:) }

  before { allow(CreditNotes::RecreditService).to receive(:call!) }

  context "when the credit note is available" do
    it "delegates to CreditNotes::RecreditService" do
      perform_job

      expect(CreditNotes::RecreditService).to have_received(:call!).with(credit:)
    end
  end

  context "when the credit note is voided" do
    let(:credit_note) do
      create(:credit_note, organization:, customer:, invoice: source_invoice, credit_status: :voided)
    end

    it "does not call CreditNotes::RecreditService" do
      perform_job

      expect(CreditNotes::RecreditService).not_to have_received(:call!)
    end
  end

  context "when the credit note is nil" do
    let(:credit) { create(:credit_note_credit, organization:, invoice:, credit_note: nil) }

    it "does not call CreditNotes::RecreditService" do
      perform_job

      expect(CreditNotes::RecreditService).not_to have_received(:call!)
    end
  end
end
