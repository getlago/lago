# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CreditNotes::RetryTaxReporting do
  let(:required_permission) { "credit_notes:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:user) { membership.user }

  let(:invoice) do
    create(
      :invoice,
      :with_subscriptions,
      organization:,
      customer:,
      subscriptions: [subscription],
      currency: "EUR"
    )
  end

  let(:credit_note) do
    create(
      :credit_note,
      :with_tax_error,
      organization:,
      customer:,
      invoice:
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
  let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
  let(:body) do
    path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
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
      mutation($input: RetryTaxReportingInput!) {
        retryTaxReporting(input: $input) {
          id
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
  it_behaves_like "requires permission", "credit_notes:update"

  context "with valid preconditions" do
    it "returns the credit note after successful retry" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: credit_note.id}
        }
      )

      data = result["data"]["retryTaxReporting"]

      expect(data["id"]).to eq(credit_note.id)
    end
  end

  context "when there is tax error" do
    let(:body) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
      File.read(path)
    end

    it "returns the error" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: credit_note.id}
        }
      )

      expect_graphql_error(
        result:,
        message: "Unprocessable Entity"
      )
    end
  end
end
