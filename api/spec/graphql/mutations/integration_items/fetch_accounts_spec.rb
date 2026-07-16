# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::IntegrationItems::FetchAccounts do
  let(:required_permission) { "organization:integrations:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:integration_item) { create(:integration_item, integration:) }
  let(:sync_service) { instance_double(Integrations::Aggregator::SyncService) }

  let(:accounts_response) do
    File.read(Rails.root.join("spec/fixtures/integration_aggregator/accounts_response.json"))
  end

  let(:mutation) do
    <<~GQL
      mutation($input: FetchIntegrationAccountsInput!) {
        fetchIntegrationAccounts(input: $input) {
          collection { externalName, externalAccountCode, externalId }
        }
      }
    GQL
  end

  let(:account_ids) do
    %w[12ec4c59-ad56-4a4f-93eb-fb0a7740f4e2 6317441d-6547-417c-89e2-6e43ece791d8 80701036-73b5-4468-a4b3-a139262035b4]
  end

  before do
    allow(Integrations::Aggregator::SyncService).to receive(:call).and_return(BaseResult.new)

    stub_request(:get, "https://api.nango.dev/v1/netsuite/accounts?limit=450")
      .to_return(status: 200, body: accounts_response, headers: {})

    integration_item
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "fetches the integration accounts" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {integrationId: integration.id}
      }
    )

    result_data = result["data"]["fetchIntegrationAccounts"]

    ids = result_data["collection"].map { |value| value["externalId"] }

    expect(ids).to eq(account_ids)
    expect(integration.integration_items.where(item_type: :account).count).to eq(3)
  end
end
