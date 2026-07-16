# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::AdjustedFees::Create, :premium do
  let(:required_permission) { "invoices:update" }
  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:) }
  let(:invoice) { create(:invoice, invoice_type: :subscription, organization:, customer:) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:, started_at: Time.current - 1.year) }

  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      invoice:,
      subscription:,
      timestamp: Time.current,
      from_datetime: Time.current.beginning_of_month,
      to_datetime: Time.current.end_of_month,
      charges_from_datetime: Time.current.beginning_of_month - 1.month,
      charges_to_datetime: (Time.current - 1.month).end_of_month
    )
  end

  let(:fee) do
    create(
      :charge_fee,
      subscription:,
      invoice:,
      charge:,
      properties: {
        from_datetime: invoice_subscription.from_datetime,
        to_datetime: invoice_subscription.to_datetime,
        charges_from_datetime: invoice_subscription.charges_from_datetime,
        charges_to_datetime: invoice_subscription.charges_to_datetime,
        timestamp: invoice_subscription.timestamp
      }
    )
  end

  let(:input) do
    {
      feeId: fee.id,
      invoiceId: invoice.id,
      units: 4,
      unitPreciseAmount: "10.00001",
      invoiceDisplayName: "Hello"
    }
  end

  let(:mutation) do
    <<-GQL
      mutation($input: CreateAdjustedFeeInput!) {
        createAdjustedFee(input: $input) {
          id,
          units,
          invoiceDisplayName
          adjustedFee
        }
      }
    GQL
  end

  before { fee.invoice.draft! }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  it "creates an adjusted fee" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {input:}
    )

    expect(result["data"]["createAdjustedFee"]["id"]).to be_present
    expect(result["data"]["createAdjustedFee"]["adjustedFee"]).to be_truthy
    expect(result["data"]["createAdjustedFee"]["units"]).to eq(4)
    expect(result["data"]["createAdjustedFee"]["invoiceDisplayName"]).to eq("Hello")
  end

  context "without an existing fee" do
    let(:billable_metric2) { create(:billable_metric, organization:) }
    let(:charge2) { create(:standard_charge, plan:, billable_metric: billable_metric2) }

    let(:input) do
      {
        invoiceId: invoice.id,
        chargeId: charge2.id,
        subscriptionId: subscription.id,
        units: 4,
        unitPreciseAmount: "10.00001",
        invoiceDisplayName: "Hello"
      }
    end

    it "creates an adjusted fee" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect(result["data"]["createAdjustedFee"]["id"]).to be_present
      expect(result["data"]["createAdjustedFee"]["adjustedFee"]).to be_truthy
      expect(result["data"]["createAdjustedFee"]["units"]).to eq(4)
      expect(result["data"]["createAdjustedFee"]["invoiceDisplayName"]).to eq("Hello")
    end
  end

  context "with finalized invoice" do
    before { fee.invoice.finalized! }

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect_forbidden_error(result)
    end
  end
end
