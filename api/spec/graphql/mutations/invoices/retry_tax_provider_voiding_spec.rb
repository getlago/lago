# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::RetryTaxProviderVoiding do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:, payment_provider: "gocardless") }
  let(:user) { membership.user }

  let(:invoice) do
    create(
      :invoice,
      :voided,
      :with_tax_voiding_error,
      :subscription,
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

  let(:integration) { create(:anrok_integration, organization:) }
  let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
  let(:response) { instance_double(Net::HTTPOK) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/anrok/void_invoices" }
  let(:body) do
    path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response_void.json")
    File.read(path)
  end
  let(:integration_collection_mapping) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :fallback_item,
      settings: {external_id: "1", external_account_code: "11", external_name: ""}
    )
  end
  let(:mutation) do
    <<-GQL
      mutation($input: RetryTaxProviderVoidingInput!) {
        retryTaxProviderVoiding(input: $input) {
          id
          status
        }
      }
    GQL
  end

  before do
    integration_collection_mapping
    fee_subscription

    integration_customer

    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
    allow(lago_client).to receive(:post_with_response).and_return(response)
    allow(response).to receive(:body).and_return(body)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  context "with valid preconditions" do
    it "returns the invoice after successful retry" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: invoice.id}
        }
      )

      data = result["data"]["retryTaxProviderVoiding"]

      expect(data["id"]).to eq(invoice.id)
      expect(data["status"]).to eq("voided")
    end
  end
end
