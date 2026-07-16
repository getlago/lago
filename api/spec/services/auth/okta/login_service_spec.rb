# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Okta::LoginService, cache: :memory do
  let(:service) { described_class.new(code:, state:) }
  let(:okta_integration) { create(:okta_integration, domain: "bar.com", organization_name: "foo") }
  let(:lago_http_client) { instance_double(LagoHttpClient::Client) }
  let(:okta_token_response) { OpenStruct.new(body: {access_token: "access_token"}) }
  let(:okta_userinfo_response) { OpenStruct.new({email: "foo@bar.com"}) }
  let(:state) { SecureRandom.uuid }
  let(:code) { "code" }

  before do
    okta_integration

    Rails.cache.write(state, "foo@bar.com") if state.present?

    if okta_integration
      okta_integration.organization.premium_integrations << "okta"
      okta_integration.organization.save!
      okta_integration.organization.enable_okta_authentication!
    end

    allow(LagoHttpClient::Client).to receive(:new).and_return(lago_http_client)
    allow(lago_http_client).to receive(:post_url_encoded).and_return(okta_token_response)
    allow(lago_http_client).to receive(:get).and_return(okta_userinfo_response)
  end

  describe "#call", :premium do
    before { allow(UserDevices::RegisterService).to receive(:call!) }

    it "registers the user device" do
      result = service.call

      expect(UserDevices::RegisterService).to have_received(:call!).with(user: result.user)
    end

    it "creates user, membership and authenticate user" do
      result = service.call

      expect(result).to be_success
      expect(result.user.email).to eq("foo@bar.com")
      expect(result.token).to be_present

      decoded = Auth::TokenService.decode(token: result.token)
      expect(decoded["login_method"]).to eq(Organizations::AuthenticationMethods::OKTA)
    end

    context "when code is not provided" do
      let(:code) { nil }

      it "returns error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages).to eq({base: ["code_not_found"]})
      end
    end

    context "when state is not provided" do
      let(:state) { nil }

      it "returns error" do
        result = service.call
        expect(result).not_to be_success
        expect(result.error.messages).to eq({base: ["state_not_found"]})
      end
    end

    context "when the login method is not allowed" do
      let(:user) { create(:user, email: "foo@bar.com") }
      let(:membership) { create(:membership, user:, organization: okta_integration.organization) }

      before { okta_integration.organization.disable_okta_authentication! }

      it "returns error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages).to match(okta: ["login_method_not_authorized"])
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

    context "when okta userinfo email is different from the state one" do
      let(:okta_userinfo_response) { OpenStruct.new({email: "foo@test.com"}) }

      it "returns error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("okta_userinfo_error")
      end
    end

    context "when user already exists" do
      let(:user) { create(:user, email: "foo@bar.com") }

      before { user }

      it "does not create a new user" do
        expect { service.call }.not_to change(User, :count)
      end
    end

    context "when membership already exists" do
      let(:user) { create(:user, email: "foo@bar.com") }
      let(:membership) { create(:membership, user:, organization: okta_integration.organization) }

      before { membership }

      it "does not create a new membership" do
        expect { service.call }.not_to change(Membership, :count)
      end
    end
  end
end
