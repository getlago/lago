# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::FinalizeAll do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:user) { membership.user }
  let(:customer) { create(:customer, organization:) }

  let(:invoice) do
    create(
      :invoice,
      :draft,
      :with_subscriptions,
      organization:,
      customer:,
      subscriptions: [subscription],
      currency: "EUR"
    )
  end

  let(:subscription) do
    create(
      :subscription,
      plan:,
      subscription_at: started_at,
      started_at:,
      created_at: started_at
    )
  end

  let(:timestamp) { Time.zone.now - 1.year }
  let(:started_at) { Time.zone.now - 2.years }
  let(:plan) { create(:plan, organization:, interval: "monthly") }
  let(:fee_subscription) do
    create(
      :fee,
      invoice:,
      subscription:,
      fee_type: :subscription,
      amount_cents: 2_000
    )
  end

  let(:mutation) do
    <<-GQL
      mutation($input: FinalizeAllInvoicesInput!) {
        finalizeAllInvoices(input: $input) {
          collection { id }
        }
      }
    GQL
  end

  before do
    fee_subscription
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  context "with valid preconditions" do
    it "returns the invoices that are scheduled for finalize" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {}
        }
      )

      data = result["data"]["finalizeAllInvoices"]
      invoice_ids = data["collection"].map { |value| value["id"] }

      expect(invoice_ids).to include(invoice.id)
    end
  end
end
