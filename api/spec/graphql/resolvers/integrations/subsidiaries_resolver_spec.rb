# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Integrations::SubsidiariesResolver do
  let(:required_permission) { "organization:integrations:view" }
  let(:query) do
    <<~GQL
      query($integrationId: ID!) {
        integrationSubsidiaries(integrationId: $integrationId) {
           collection { externalId externalName }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:subsidiaries_endpoint) { "https://api.nango.dev/v1/netsuite/subsidiaries" }

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "netsuite-tba"
    }
  end

  let(:aggregator_response) do
    path = Rails.root.join("spec/fixtures/integration_aggregator/subsidiaries_response.json")
    JSON.parse(File.read(path))
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(subsidiaries_endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
    allow(lago_client).to receive(:get)
      .with(headers:)
      .and_return(aggregator_response)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:view"

  it "returns a list of subsidiaries" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {integrationId: integration.id}
    )

    subsidiaries = result["data"]["integrationSubsidiaries"]

    expect(subsidiaries["collection"].count).to eq(4)
    expect(subsidiaries["collection"].first["externalId"]).to eq("1")
  end
end
