# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntities::UpdateInvoiceIssuingDateSettingsService do
  include ActiveJob::TestHelper

  subject(:update_service) { described_class.new(billing_entity:, params:) }

  let(:billing_entity) { create(:billing_entity, invoice_grace_period: 9) }
  let(:organization) { billing_entity.organization }
  let(:customer) { create(:customer, organization:, net_payment_term: 5) }
  let(:params) do
    {
      subscription_invoice_issuing_date_anchor: "current_period_end",
      subscription_invoice_issuing_date_adjustment: "align_with_finalization_date",
      invoice_grace_period: 15
    }
  end

  describe "#call" do
    let!(:invoice_draft) do
      create(
        :invoice,
        customer:,
        billing_entity:,
        status: :draft,
        issuing_date: DateTime.parse("19 Jun 2022").to_date,
        applied_grace_period: 9
      )
    end

    context "with premium feature", :premium do
      it "updates invoice issuing date settings on billing_entity" do
        update_service.call

        billing_entity.reload

        expect(billing_entity.invoice_grace_period).to eq(15)
        expect(billing_entity.subscription_invoice_issuing_date_anchor).to eq("current_period_end")
        expect(billing_entity.subscription_invoice_issuing_date_adjustment).to eq("align_with_finalization_date")
      end

      it "updates issuing_date and payment_due_date on draft invoices" do
        expect { update_service.call }.to enqueue_job(Invoices::UpdateAllInvoiceIssuingDateFromBillingEntityJob).with(
          billing_entity,
          subscription_invoice_issuing_date_anchor: "next_period_start",
          subscription_invoice_issuing_date_adjustment: "align_with_finalization_date",
          invoice_grace_period: 9
        )
      end
    end

    context "without premium feature" do
      it "does not update invoice_grace_period on billing_entity" do
        update_service.call

        billing_entity.reload

        expect(billing_entity.invoice_grace_period).not_to eq(15)
        expect(billing_entity.subscription_invoice_issuing_date_anchor).to eq("current_period_end")
        expect(billing_entity.subscription_invoice_issuing_date_adjustment).to eq("align_with_finalization_date")
      end

      it "updates issuing_date and payment_due_date on draft invoices" do
        expect { update_service.call }.not_to change { invoice_draft.reload.issuing_date }
      end
    end

    context "when grace_period is the same as the current one on the billing_entity" do
      let(:grace_period) { billing_entity.invoice_grace_period }

      it "does not update issuing_date on draft invoices" do
        expect { update_service.call }.not_to change { invoice_draft.reload.issuing_date }
      end
    end
  end
end
