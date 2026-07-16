# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::UpdateAllInvoiceIssuingDateFromBillingEntityService do
  subject { described_class.new(billing_entity:, previous_issuing_date_settings:) }

  let(:billing_entity) { create(:billing_entity) }
  let(:organization) { billing_entity.organization }
  let(:previous_issuing_date_settings) do
    {
      subscription_invoice_issuing_date_anchor: "current_period_end",
      subscription_invoice_issuing_date_adjustment: "keep_anchor",
      invoice_grace_period: 3
    }
  end

  context "when billing entity does not have invoices" do
    it "enqueues zero jobs" do
      expect { subject.call }
        .not_to enqueue_job(Invoices::UpdateIssuingDateFromBillingEntityJob)
    end
  end

  context "when billing entity has draft invoices" do
    let(:draft_invoice) { create(:invoice, :draft, organization:) }

    before { draft_invoice }

    it "enqueues 1 job for the draft invoice" do
      expect { subject.call }
        .to enqueue_job(Invoices::UpdateIssuingDateFromBillingEntityJob)
        .with(draft_invoice, previous_issuing_date_settings)
    end
  end

  context "when billing entity has finalized invoices" do
    let(:finalized_invoice) { create(:invoice, :finalized, organization:) }

    before { finalized_invoice }

    it "enqueues zero jobs" do
      expect { subject.call }
        .not_to enqueue_job(Invoices::UpdateIssuingDateFromBillingEntityJob)
    end
  end
end
