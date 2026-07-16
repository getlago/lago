# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Superset::DashboardsResolver do
  let(:required_permission) { "analytics:view" }
  let(:query) do
    <<~GQL
      query {
        supersetDashboards {
          id
          dashboardTitle
          embeddedId
          guestToken
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:dashboards) do
    [
      {
        id: "1",
        dashboard_title: "Sales Dashboard",
        embedded_id: "embedded-uuid-1",
        guest_token: "guest-token-1"
      },
      {
        id: "2",
        dashboard_title: "Analytics Dashboard",
        embedded_id: "embedded-uuid-2",
        guest_token: "guest-token-2"
      }
    ]
  end

  let(:result) do
    BaseService::Result.new.tap do |result|
      result.dashboards = dashboards
    end
  end

  before do
    allow(Auth::SupersetService).to receive(:call).and_return(result)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "analytics:view"

  it "returns a list of Superset dashboards" do
    graphql_result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    dashboards_response = graphql_result["data"]["supersetDashboards"]

    expect(dashboards_response).to be_an(Array)
    expect(dashboards_response.size).to eq(2)

    expect(dashboards_response[0]["id"]).to eq("1")
    expect(dashboards_response[0]["dashboardTitle"]).to eq("Sales Dashboard")
    expect(dashboards_response[0]["embeddedId"]).to eq("embedded-uuid-1")
    expect(dashboards_response[0]["guestToken"]).to eq("guest-token-1")

    expect(dashboards_response[1]["id"]).to eq("2")
    expect(dashboards_response[1]["dashboardTitle"]).to eq("Analytics Dashboard")
    expect(dashboards_response[1]["embeddedId"]).to eq("embedded-uuid-2")
    expect(dashboards_response[1]["guestToken"]).to eq("guest-token-2")

    expect(Auth::SupersetService).to have_received(:call).with(
      organization: organization,
      user: nil
    )
  end

  context "when no dashboards exist" do
    let(:dashboards) { [] }

    it "returns an empty array" do
      graphql_result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      dashboards_response = graphql_result["data"]["supersetDashboards"]

      expect(dashboards_response).to eq([])
    end
  end

  context "when the superset service fails" do
    let(:result) do
      BaseService::Result.new.tap do |r|
        r.service_failure!(code: "superset_auth_failed", message: "Failed to authenticate with Superset")
      end
    end

    it "returns an error" do
      graphql_result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect(graphql_result["errors"]).to be_present
      expect(graphql_result["errors"].first["extensions"]["code"]).to eq("superset_auth_failed")
    end
  end
end
