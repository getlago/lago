# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::AdjustedFees::Preview do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) do
    create(
      :invoice,
      :voided,
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
    <<~GQL
      mutation($input: PreviewAdjustedFeeInput!) {
        previewAdjustedFee(input: $input) {
          id
          invoiceDisplayName
          units
          preciseUnitAmount
        }
      }
    GQL
  end

  let(:input) do
    {
      invoiceId: invoice.id,
      feeId: fee_subscription.id,
      units: 10,
      unitPreciseAmount: "500",
      invoiceDisplayName: "Previewed Fee"
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  it "previews an adjusted fee" do
    freeze_time do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: input}
      )

      data = result.dig("data", "previewAdjustedFee")
      expect(data["id"]).to be_present
      expect(data["invoiceDisplayName"]).to eq("Previewed Fee")
      expect(data["units"]).to eq(10)
      expect(data["preciseUnitAmount"]).to eq(500)
    end
  end
end
