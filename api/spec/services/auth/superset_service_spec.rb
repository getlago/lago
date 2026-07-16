# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::SupersetService do
  subject(:service) { described_class.new(organization:, user:) }

  let(:organization) { create(:organization, name: "Test Org") }
  let(:user) { nil }

  let(:superset_url) { "http://localhost:8089" }
  let(:superset_username) { "admin" }
  let(:superset_password) { "admin" }

  before do
    stub_const("ENV", ENV.to_h.merge(
      "SUPERSET_URL" => superset_url,
      "SUPERSET_USERNAME" => superset_username,
      "SUPERSET_PASSWORD" => superset_password
    ))
  end

  describe ".call" do
    let(:access_token) { "access_token_123" }
    let(:csrf_token) { "csrf_token_456" }
    let(:guest_token_1) { "guest_token_dashboard_1" }
    let(:guest_token_2) { "guest_token_dashboard_2" }
    let(:embedded_uuid_1) { "embedded-uuid-1" }
    let(:embedded_uuid_2) { "embedded-uuid-2" }

    let(:auth_response) { {access_token:}.to_json }
    let(:csrf_response) { {result: csrf_token}.to_json }
    let(:dashboards_response) do
      {
        result: [
          {id: "1", dashboard_title: "Dashboard 1"},
          {id: "2", dashboard_title: "Dashboard 2"}
        ]
      }.to_json
    end

    let(:embedded_exists_response_1) { {result: {uuid: embedded_uuid_1}}.to_json }
    let(:embedded_create_response_2) { {result: {uuid: embedded_uuid_2}}.to_json }
    let(:guest_token_response_1) { {token: guest_token_1}.to_json }
    let(:guest_token_response_2) { {token: guest_token_2}.to_json }

    context "when authentication and dashboard processing is successful" do
      before do
        stub_request(:post, "#{superset_url}/api/v1/security/login")
          .with(
            body: {username: superset_username, password: superset_password, provider: "db"}.to_json
          )
          .to_return(
            status: 200,
            body: auth_response,
            headers: {"Content-Type" => "application/json"}
          )

        stub_request(:get, "#{superset_url}/api/v1/security/csrf_token/")
          .to_return(status: 200, body: csrf_response)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/")
          .to_return(status: 200, body: dashboards_response)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/1/embedded")
          .to_return(status: 200, body: embedded_exists_response_1)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/2/embedded")
          .to_return(status: 404, body: {}.to_json)

        stub_request(:post, "#{superset_url}/api/v1/dashboard/2/embedded")
          .with(body: {allowed_domains: []}.to_json)
          .to_return(status: 200, body: embedded_create_response_2)

        stub_request(:post, "#{superset_url}/api/v1/security/guest_token/")
          .with(body: hash_including(resources: [{id: "1", type: "dashboard"}]))
          .to_return(status: 200, body: guest_token_response_1)

        stub_request(:post, "#{superset_url}/api/v1/security/guest_token/")
          .with(body: hash_including(resources: [{id: "2", type: "dashboard"}]))
          .to_return(status: 200, body: guest_token_response_2)
      end

      it "returns success with all dashboards" do
        result = service.call

        expect(result).to be_success
        expect(result.dashboards).to be_an(Array)
        expect(result.dashboards.size).to eq(2)

        dashboard_1 = result.dashboards.find { |d| d[:id] == "1" }
        expect(dashboard_1[:dashboard_title]).to eq("Dashboard 1")
        expect(dashboard_1[:embedded_id]).to eq(embedded_uuid_1)
        expect(dashboard_1[:guest_token]).to eq(guest_token_1)

        dashboard_2 = result.dashboards.find { |d| d[:id] == "2" }
        expect(dashboard_2[:dashboard_title]).to eq("Dashboard 2")
        expect(dashboard_2[:embedded_id]).to eq(embedded_uuid_2)
        expect(dashboard_2[:guest_token]).to eq(guest_token_2)
      end
    end

    context "when custom user info is provided" do
      let(:user) do
        {
          first_name: "John",
          last_name: "Doe",
          username: "john.doe"
        }
      end

      before do
        stub_request(:post, "#{superset_url}/api/v1/security/login")
          .to_return(status: 200, body: auth_response, headers: {"Content-Type" => "application/json"})

        stub_request(:get, "#{superset_url}/api/v1/security/csrf_token/")
          .to_return(status: 200, body: csrf_response)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/")
          .to_return(status: 200, body: {result: [{id: "1", dashboard_title: "Test"}]}.to_json)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/1/embedded")
          .to_return(status: 200, body: {result: {uuid: embedded_uuid_1}}.to_json)

        stub_request(:post, "#{superset_url}/api/v1/security/guest_token/")
          .with(
            body: hash_including(
              user: {
                first_name: "John",
                last_name: "Doe",
                username: "john.doe"
              }
            )
          )
          .to_return(status: 200, body: {token: guest_token_1}.to_json)
      end

      it "uses the provided user info" do
        result = service.call

        expect(result).to be_success
        expect(result.dashboards.size).to eq(1)
      end
    end

    context "when authentication fails" do
      before do
        stub_request(:post, "#{superset_url}/api/v1/security/login")
          .to_return(status: 401, body: "Invalid credentials")
      end

      it "returns a service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("superset_auth_failed")
        expect(result.error.error_message).to include("Failed to authenticate with Superset")
      end
    end

    context "when authentication succeeds but no access token is returned" do
      before do
        stub_request(:post, "#{superset_url}/api/v1/security/login")
          .to_return(status: 200, body: {}.to_json, headers: {"Content-Type" => "application/json"})
      end

      it "returns a service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("superset_auth_failed")
        expect(result.error.error_message).to include("No access token received from Superset")
      end
    end

    context "when getting CSRF token fails" do
      before do
        stub_request(:post, "#{superset_url}/api/v1/security/login")
          .to_return(status: 200, body: auth_response, headers: {"Content-Type" => "application/json"})

        stub_request(:get, "#{superset_url}/api/v1/security/csrf_token/")
          .to_return(status: 500, body: {message: "Internal error"}.to_json)
      end

      it "returns a service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("superset_csrf_failed")
        expect(result.error.error_message).to include("Failed to get CSRF token")
      end
    end

    context "when fetching dashboards fails" do
      before do
        stub_request(:post, "#{superset_url}/api/v1/security/login")
          .to_return(status: 200, body: auth_response, headers: {"Content-Type" => "application/json"})

        stub_request(:get, "#{superset_url}/api/v1/security/csrf_token/")
          .to_return(status: 200, body: csrf_response)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/")
          .to_return(status: 500, body: {message: "Internal error"}.to_json)
      end

      it "returns a service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("superset_fetch_dashboards_failed")
        expect(result.error.error_message).to include("Failed to fetch dashboards")
      end
    end

    context "when creating embedded config fails" do
      before do
        stub_request(:post, "#{superset_url}/api/v1/security/login")
          .to_return(status: 200, body: auth_response, headers: {"Content-Type" => "application/json"})

        stub_request(:get, "#{superset_url}/api/v1/security/csrf_token/")
          .to_return(status: 200, body: csrf_response)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/")
          .to_return(status: 200, body: {result: [{id: "1", dashboard_title: "Test"}]}.to_json)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/1/embedded")
          .to_return(status: 404, body: {}.to_json)

        stub_request(:post, "#{superset_url}/api/v1/dashboard/1/embedded")
          .to_return(status: 500, body: {message: "Failed to create"}.to_json)
      end

      it "returns success with empty dashboards array" do
        result = service.call

        expect(result).to be_success
        expect(result.dashboards).to be_empty
      end
    end

    context "when no dashboards exist" do
      before do
        stub_request(:post, "#{superset_url}/api/v1/security/login")
          .to_return(status: 200, body: auth_response, headers: {"Content-Type" => "application/json"})

        stub_request(:get, "#{superset_url}/api/v1/security/csrf_token/")
          .to_return(status: 200, body: csrf_response)

        stub_request(:get, "#{superset_url}/api/v1/dashboard/")
          .to_return(status: 200, body: {result: []}.to_json)
      end

      it "returns success with empty dashboards array" do
        result = service.call

        expect(result).to be_success
        expect(result.dashboards).to eq([])
      end
    end

    context "when environment variables are missing" do
      before do
        stub_const("ENV", ENV.to_h.except("SUPERSET_URL"))
      end

      it "returns a service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("superset_missing_configuration")
        expect(result.error.error_message).to include("Superset configuration is incomplete")
        expect(result.error.error_message).to include("SUPERSET_URL")
      end
    end
  end
end
