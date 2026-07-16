# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntities::Taxes::RefreshDraftInvoicesJob do
  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }

  it "marks draft invoices of the billing entity as ready to be refreshed" do
    draft_invoice = create(:invoice, :draft, organization:, billing_entity:)
    finalized_invoice = create(:invoice, organization:, billing_entity:)
    other_billing_entity = create(:billing_entity, organization:)
    other_draft_invoice = create(:invoice, :draft, organization:, billing_entity: other_billing_entity)

    described_class.perform_now(billing_entity.id)

    expect(draft_invoice.reload.ready_to_be_refreshed).to be true
    expect(finalized_invoice.reload.ready_to_be_refreshed).to be false
    expect(other_draft_invoice.reload.ready_to_be_refreshed).to be false
  end

  it "is a no-op when the billing entity does not exist" do
    expect { described_class.perform_now("nonexistent-id") }.not_to raise_error
  end
end
