# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::UpdateIssuingDateFromBillingEntityService do
  subject { described_class.new(invoice:, previous_issuing_date_settings:) }

  let(:invoice) do
    create(:invoice, :draft, customer:, issuing_date:, expected_finalization_date:, payment_due_date:, applied_grace_period: 12)
  end

  let(:customer) { create(:customer) }
  let(:issuing_date) { Time.current + old_grace_period.days }
  let(:expected_finalization_date) { Time.current + old_grace_period.days }
  let(:payment_due_date) { issuing_date }

  let(:previous_issuing_date_settings) do
    {
      subscription_invoice_issuing_date_anchor: "next_period_start",
      subscription_invoice_issuing_date_adjustment: "align_with_finalization_date",
      invoice_grace_period: old_grace_period
    }
  end

  let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
  let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

  let(:old_grace_period) { 12 }
  let(:new_grace_period) { 1 }

  before do
    invoice.billing_entity.update!(
      subscription_invoice_issuing_date_anchor:,
      subscription_invoice_issuing_date_adjustment:,
      invoice_grace_period: new_grace_period
    )
  end

  shared_examples "does not change invoice dates" do
    it "does not change the issuing_date" do
      expect { subject.call }.not_to change { invoice.reload.issuing_date }
    end

    it "does not change the applied_grace_period" do
      expect { subject.call }.not_to change { invoice.reload.applied_grace_period }
    end

    it "does not change the payment due date" do
      expect { subject.call }.not_to change { invoice.reload.payment_due_date }
    end
  end

  context "when customer has invoice_grace_period" do
    before do
      invoice.customer.update!(invoice_grace_period: 12)
    end

    it_behaves_like "does not change invoice dates"
  end

  context "when invoice is not draft" do
    before do
      invoice.finalized!
    end

    it_behaves_like "does not change invoice dates"
  end

  context "when going from 12 to 15 days" do
    let(:new_grace_period) { 15 }

    it "changes the issuing_date by 3 days" do
      expect { subject.call }.to change(invoice, :issuing_date).by(3)
    end

    it "changes the expected_finalization_date by 3 days" do
      expect { subject.call }.to change(invoice, :expected_finalization_date).by(3)
    end

    it "changes the applied_grace_to 15" do
      expect { subject.call }.to change(invoice, :applied_grace_period).to(15)
    end

    it "changes the payment_due_date by 3 days" do
      expect { subject.call }.to change(invoice, :payment_due_date).by(3)
    end
  end

  context "when going from 12 to 9 days" do
    let(:new_grace_period) { 9 }

    it "changes the issuing_date by 3 days" do
      expect { subject.call }.to change(invoice, :issuing_date).by(-3)
    end

    it "changes the expected_finalization_date by 3 days" do
      expect { subject.call }.to change(invoice, :expected_finalization_date).by(-3)
    end

    it "changes the applied_grace_to 9" do
      expect { subject.call }.to change(invoice, :applied_grace_period).to(9)
    end

    it "changes the payment_due_date by 3 days" do
      expect { subject.call }.to change(invoice, :payment_due_date).by(-3)
    end
  end

  context "with issuing date preferences" do
    let(:recurring) { true }

    before do
      create(:invoice_subscription, invoice:, recurring:)
    end

    context "with current_period_end + keep_anchor" do
      let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
      let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
      let(:new_grace_period) { 2 }

      it "updates issuing_date and expected_finalization_date" do
        expect { subject.call }.to change(invoice, :issuing_date).by(-13)
          .and change(invoice, :expected_finalization_date).by(-10)
      end
    end

    context "with current_period_end + align_with_finalization_date" do
      let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
      let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }
      let(:new_grace_period) { 2 }

      it "updates issuing_date and expected_finalization_date" do
        expect { subject.call }.to change(invoice, :issuing_date).by(-10)
          .and change(invoice, :expected_finalization_date).by(-10)
      end
    end

    context "with next_period_start + keep_anchor" do
      let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
      let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
      let(:new_grace_period) { 2 }

      it "updates issuing_date and expected_finalization_date" do
        expect { subject.call }.to change(invoice, :issuing_date).by(-12)
          .and change(invoice, :expected_finalization_date).by(-10)
      end
    end

    context "with next_period_start + align_with_finalization_date" do
      let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
      let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }
      let(:new_grace_period) { 2 }

      it "updates issuing_date and expected_finalization_date" do
        expect { subject.call }.to change(invoice, :issuing_date).by(-10)
          .and change(invoice, :expected_finalization_date).by(-10)
      end
    end

    context "with preferences set on the customer level" do
      let(:customer) do
        create(
          :customer,
          subscription_invoice_issuing_date_anchor: "current_period_end",
          subscription_invoice_issuing_date_adjustment: "align_with_finalization_date",
          invoice_grace_period: 12
        )
      end

      let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
      let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
      let(:new_grace_period) { 2 }

      it "ignores billing_entity issuing date preferences" do
        expect { subject.call }.not_to change(invoice, :issuing_date)
      end

      it "ignores billing_entity inovice_grace_period" do
        expect { subject.call }.not_to change(invoice, :expected_finalization_date)
      end
    end

    context "when invoice is not recurring" do
      let(:recurring) { false }

      let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
      let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
      let(:new_grace_period) { 2 }

      it "ignores all issuing date preferences" do
        expect { subject.call }.to change(invoice, :issuing_date).by(-10)
      end

      it "applies new invoice_grace_period to expected_finalization_date" do
        expect { subject.call }.to change(invoice, :expected_finalization_date).by(-10)
      end
    end
  end
end
