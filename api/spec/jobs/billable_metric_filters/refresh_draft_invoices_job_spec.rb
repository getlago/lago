# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetricFilters::RefreshDraftInvoicesJob do
  let(:organization) { create(:organization) }
  let(:billable_metric) { create(:billable_metric, organization:) }

  it "marks matching draft invoices as ready to be refreshed" do
    plan = create(:plan, organization:)
    create(:standard_charge, plan:, billable_metric:)
    subscription = create(:subscription, plan:)
    draft_invoice = create(:invoice, :draft, organization:, customer: subscription.customer)
    create(:invoice_subscription, invoice: draft_invoice, subscription:)
    finalized_invoice = create(:invoice, organization:, customer: subscription.customer)

    described_class.perform_now(billable_metric.id)

    expect(draft_invoice.reload.ready_to_be_refreshed).to be true
    expect(finalized_invoice.reload.ready_to_be_refreshed).to be false
  end

  it "is a no-op when the billable metric does not exist" do
    expect { described_class.perform_now("nonexistent-id") }.not_to raise_error
  end
end
