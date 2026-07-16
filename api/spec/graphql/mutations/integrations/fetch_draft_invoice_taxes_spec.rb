# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::FetchDraftInvoiceTaxes do
  let(:required_permission) { "invoices:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:integration) { create(:anrok_integration, organization:) }
  let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
  let(:currency) { "EUR" }
  let(:customer) { create(:customer, organization:) }
  let(:add_on_first) { create(:add_on, organization:) }
  let(:add_on_second) { create(:add_on, amount_cents: 400, organization:) }
  let(:response) { instance_double(Net::HTTPOK) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/anrok/draft_invoices" }
  let(:current_time) { DateTime.new(2023, 7, 19, 12, 12) }
  let(:fees) do
    [
      {
        addOnId: add_on_first.id,
        unitAmountCents: 1200,
        units: 2,
        description: "desc-123",
        invoiceDisplayName: "fee-123",
        fromDatetime: current_time.utc.iso8601(3),
        toDatetime: current_time.utc.iso8601(3)
      },
      {
        addOnId: add_on_second.id,
        unitAmountCents: 400,
        units: 1,
        description: "desc-12345",
        invoiceDisplayName: "fee-12345",
        fromDatetime: current_time.utc.iso8601(3),
        toDatetime: current_time.utc.iso8601(3)
      }
    ]
  end
  let(:integration_collection_mapping1) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :fallback_item,
      settings: {external_id: "1", external_account_code: "11", external_name: ""}
    )
  end
  let(:integration_mapping_add_on) do
    create(
      :netsuite_mapping,
      integration:,
      mappable_type: "AddOn",
      mappable_id: add_on_first.id,
      settings: {external_id: "m1", external_account_code: "m11", external_name: ""}
    )
  end
  let(:body) do
    path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
    File.read(path)
  end
  let(:mutation) do
    <<-GQL
      mutation($input: FetchDraftInvoiceTaxesInput!) {
        fetchDraftInvoiceTaxes(input: $input) {
          collection {
            itemId
            itemCode
            amountCents
            taxAmountCents
            taxBreakdown {
              name
              rate
              taxAmount
              type
              enumedTaxCode
            }
          }
        }
      }
    GQL
  end

  before do
    integration_customer
    integration_collection_mapping1
    integration_mapping_add_on

    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
    allow(lago_client).to receive(:post_with_response).and_return(response)
    allow(response).to receive(:body).and_return(body)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:create"

  it "fetches tax results" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          customerId: customer.id,
          currency:,
          fees:
        }
      }
    )

    result_data = result["data"]["fetchDraftInvoiceTaxes"]["collection"]

    fee = result_data.first

    expect(fee["itemId"]).to eq("lago_fee_id")
    expect(fee["itemCode"]).to eq("lago_default_b2b")
    expect(fee["amountCents"]).to eq("9900")
    expect(fee["taxAmountCents"]).to eq("990")

    breakdown1 = fee["taxBreakdown"].first

    expect(breakdown1["name"]).to eq("GST/HST")
    expect(breakdown1["rate"]).to eq(0.1)
    expect(breakdown1["taxAmount"]).to eq("990")
    expect(breakdown1["type"]).to eq("tax_exempt")
    expect(breakdown1["enumedTaxCode"]).to eq(nil)

    breakdown2 = fee["taxBreakdown"].last

    expect(breakdown2["name"]).to eq("Reverse charge")
    expect(breakdown2["rate"]).to eq(0.0)
    expect(breakdown2["taxAmount"]).to eq("0")
    expect(breakdown2["type"]).to eq("exempt")
    expect(breakdown2["enumedTaxCode"]).to eq("reverse_charge")
  end

  context "when there is tax error" do
    let(:body) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
      File.read(path)
    end

    it "returns validation error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            currency:,
            fees:
          }
        }
      )

      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(422)
      expect(response["details"]["taxError"]).to include("taxDateTooFarInFuture")
    end
  end
end
