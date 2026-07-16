# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::RegenerateFromVoided do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }

  let(:voided_invoice) do
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
      invoice: voided_invoice,
      subscription:,
      fee_type: :subscription,
      amount_cents: 2_000
    )
  end

  let(:mutation) do
    <<~GQL
      mutation($input: RegenerateInvoiceInput!) {
        regenerateFromVoided(input: $input) {
          id
          voidedInvoiceId
          fees {
            id
            invoiceDisplayName
            units
            preciseUnitAmount
          }
          status
        }
      }
    GQL
  end

  let(:fee_input) do
    {
      id: fee_subscription.id,
      chargeId: fee_subscription.charge_id,
      subscriptionId: fee_subscription.subscription_id,
      invoiceDisplayName: "Adjusted",
      units: 2,
      unitAmountCents: 5000
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  it "regenerates an invoice from a voided invoice" do
    freeze_time do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            voidedInvoiceId: voided_invoice.id,
            fees: [fee_input]
          }
        }
      )

      result_data = result.dig("data", "regenerateFromVoided")
      expect(result_data["id"]).to be_present
      expect(result_data["id"]).not_to eq(voided_invoice.id)
      expect(result_data["voidedInvoiceId"]).to eq(voided_invoice.id.to_s)
      expect(result_data["fees"].first["invoiceDisplayName"]).to eq(fee_input[:invoiceDisplayName])
      expect(result_data["fees"].first["units"]).to eq(fee_input[:units])
      expect(result_data["fees"].first["preciseUnitAmount"]).to eq(fee_input[:unitAmountCents])
      expect(result_data["status"]).to eq("finalized")
    end
  end
end
