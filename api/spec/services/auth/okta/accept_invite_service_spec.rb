# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Okta::AcceptInviteService, :premium, cache: :memory do
  subject(:service) { described_class.new(invite_token:, code:, state:) }

  let(:organization) { create(:organization, premium_integrations: ["okta"]) }
  let(:okta_integration) { create(:okta_integration, domain: "bar.com", organization_name: "foo", organization:) }
  let(:invite) { create(:invite, email: "foo@bar.com", organization:) }
  let(:invite_token) { invite.token }
  let(:lago_http_client) { instance_double(LagoHttpClient::Client) }
  let(:okta_token_response) { OpenStruct.new(body: {access_token: "access_token"}) }
  let(:okta_userinfo_response) { OpenStruct.new({email: "foo@bar.com"}) }
  let(:code) { "code" }
  let(:state) { SecureRandom.uuid }

  before do
    okta_integration
    invite_token

    organization.enable_okta_authentication!

    Rails.cache.write(state, "foo@bar.com") if state.present?

    allow(LagoHttpClient::Client).to receive(:new).and_return(lago_http_client)
    allow(lago_http_client).to receive(:post_url_encoded).and_return(okta_token_response)
    allow(lago_http_client).to receive(:get).and_return(okta_userinfo_response)
  end

  describe "#call" do
    it "creates user, membership, authenticate user and mark invite as accepted" do
      result = service.call

      expect(result).to be_success
      expect(result.user.email).to eq("foo@bar.com")
      expect(result.token).to be_present
      expect(invite.reload).to be_accepted

      decoded = Auth::TokenService.decode(token: result.token)
      expect(decoded["login_method"]).to eq(Organizations::AuthenticationMethods::OKTA)
    end

    context "when code is not provided" do
      let(:code) { nil }

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages).to eq({base: ["code_not_found"]})
      end
    end

    context "when state is not provided" do
      let(:state) { nil }

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages).to eq({base: ["state_not_found"]})
      end
    end

    context "when state is not found" do
      before do
        Rails.cache.clear
      end

      it "returns error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("state_not_found")
      end
    end

    context "when domain is not configured with an integration" do
      let(:okta_integration) { nil }

      it "returns error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("domain_not_configured")
      end
    end

    context "when pending invite does not exists" do
      let(:invite) { create(:invite, email: "foo@bar.com", status: :accepted) }

      it "returns a failure result" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("invite_not_found")
      end
    end

    context "when okta userinfo email is different from the state one" do
      let(:okta_userinfo_response) { OpenStruct.new({email: "foo@test.com"}) }

      it "returns error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("okta_userinfo_error")
      end
    end
  end
end
