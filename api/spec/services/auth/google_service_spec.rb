# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::GoogleService do
  subject(:service) { described_class.new }

  before do
    ENV["GOOGLE_AUTH_CLIENT_ID"] = "client_id"
    ENV["GOOGLE_AUTH_CLIENT_SECRET"] = "client_secret"
  end

  describe "#authorize_url" do
    it "returns the authorize url" do
      request = Rack::Request.new(Rack::MockRequest.env_for("http://example.com"))
      result = service.authorize_url(request)

      expect(result).to be_success
      expect(result.url).to include("https://accounts.google.com/o/oauth2/auth")
    end

    context "when google auth is not set up" do
      before do
        ENV["GOOGLE_AUTH_CLIENT_ID"] = nil
        ENV["GOOGLE_AUTH_CLIENT_SECRET"] = nil
      end

      it "returns a service failure" do
        request = Rack::Request.new(Rack::MockRequest.env_for("http://example.com"))
        result = service.authorize_url(request)

        expect(result).not_to be_success
        expect(result.error.code).to eq("google_auth_missing_setup")
      end
    end
  end

  describe "#login" do
    let(:authorizer) { instance_double(Google::Auth::UserAuthorizer) }
    let(:oidc_verifier) { instance_double(Google::Auth::IDTokens) }
    let(:authorizer_response) { instance_double(Google::Auth::UserRefreshCredentials, id_token: "id_token") }
    let(:oidc_response) do
      {"email" => "foo@bar.com"}
    end

    before do
      allow(Google::Auth::UserAuthorizer).to receive(:new).and_return(authorizer)
      allow(authorizer).to receive(:get_credentials_from_code).and_return(authorizer_response)
      allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_return(oidc_response)
    end

    context "when user exists" do
      before do
        user = create(:user, email: "foo@bar.com", password: "foobar")
        create(:membership, :active, user:)
        allow(UserDevices::RegisterService).to receive(:call!)
      end

      it "registers the user device" do
        result = service.login("code")

        expect(UserDevices::RegisterService).to have_received(:call!).with(user: result.user)
      end

      it "logins the user" do
        result = service.login("code")

        expect(result).to be_success
        expect(result.user).to be_a(User)
        expect(result.token).to be_present

        decoded = Auth::TokenService.decode(token: result.token)
        expect(decoded["login_method"]).to eq(Organizations::AuthenticationMethods::GOOGLE_OAUTH)
      end
    end

    context "when user does not exist" do
      it "returns a validation failure" do
        result = service.login("code")

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("user_does_not_exist")
      end
    end

    context "when login method is not allowed" do
      let(:user) { create(:user, email: "foo@bar.com", password: "foobar") }
      let(:membership) { create(:membership, :active, user:) }

      before do
        membership.organization.disable_google_oauth_authentication!
      end

      it "returns a validation failure" do
        result = service.login("code")

        expect(result).not_to be_success
        expect(result.error.messages).to match(google_oauth: ["login_method_not_authorized"])
      end
    end

    context "when user does not have active memberships" do
      before do
        create(:user, email: "foo@bar.com")
      end

      it "returns a validation failure" do
        result = service.login("code")

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("user_does_not_exist")
      end
    end

    context "when google auth is not set up" do
      before do
        ENV["GOOGLE_AUTH_CLIENT_ID"] = nil
        ENV["GOOGLE_AUTH_CLIENT_SECRET"] = nil
      end

      it "returns a service failure" do
        result = service.login("code")

        expect(result).not_to be_success
        expect(result.error.code).to eq("google_auth_missing_setup")
      end
    end
  end

  describe "#register_user" do
    let(:authorizer) { instance_double(Google::Auth::UserAuthorizer) }
    let(:oidc_verifier) { instance_double(Google::Auth::IDTokens) }
    let(:authorizer_response) { instance_double(Google::Auth::UserRefreshCredentials, id_token: "id_token") }
    let(:oidc_response) do
      {"email" => "foo@bar.com"}
    end

    before do
      create(:role, :admin)
      allow(Google::Auth::UserAuthorizer).to receive(:new).and_return(authorizer)
      allow(authorizer).to receive(:get_credentials_from_code).and_return(authorizer_response)
      allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_return(oidc_response)
      allow(UserDevices::RegisterService).to receive(:call!)
    end

    it "registers the user device" do
      result = service.register_user("code", "Foobar")

      expect(UserDevices::RegisterService).to have_received(:call!).with(user: result.user, skip_log: true)
    end

    it "register the user" do
      result = service.register_user("code", "Foobar")

      expect(result).to be_success
      expect(result.user).to be_a(User)
      expect(result.token).to be_present

      decoded = Auth::TokenService.decode(token: result.token)
      expect(decoded["login_method"]).to eq(Organizations::AuthenticationMethods::GOOGLE_OAUTH)
    end

    context "when user already exists" do
      before { create(:user, email: "foo@bar.com") }

      it "returns a validation failure" do
        result = service.register_user("code", "FooBar")

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("user_already_exists")
      end
    end

    context "when google auth is not set up" do
      before do
        ENV["GOOGLE_AUTH_CLIENT_ID"] = nil
        ENV["GOOGLE_AUTH_CLIENT_SECRET"] = nil
      end

      it "returns a service failure" do
        result = service.register_user("code", "FooBar")

        expect(result).not_to be_success
        expect(result.error.code).to eq("google_auth_missing_setup")
      end
    end
  end

  describe "#accept_invite" do
    let(:invite) { create(:invite) }
    let(:authorizer) { instance_double(Google::Auth::UserAuthorizer) }
    let(:oidc_verifier) { instance_double(Google::Auth::IDTokens) }
    let(:authorizer_response) { instance_double(Google::Auth::UserRefreshCredentials, id_token: "id_token") }
    let(:oidc_response) do
      {"email" => invite.email}
    end

    before do
      invite
      allow(Google::Auth::UserAuthorizer).to receive(:new).and_return(authorizer)
      allow(authorizer).to receive(:get_credentials_from_code).and_return(authorizer_response)
      allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_return(oidc_response)
    end

    it "accepts the invite" do
      result = service.accept_invite("code", invite.token)

      expect(result).to be_success
      expect(result.user).to be_a(User)
      expect(result.user.email).to eq(invite.email)
      expect(result.token).to be_present

      decoded = Auth::TokenService.decode(token: result.token)
      expect(decoded["login_method"]).to eq(Organizations::AuthenticationMethods::GOOGLE_OAUTH)
    end

    context "when invite does not exists" do
      it "returns a not found failure" do
        result = service.accept_invite("code", "not_a_valid_token")

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invite_not_found")
      end
    end

    context "when invite email is different from google email" do
      let(:oidc_response) do
        {"email" => "foo@bar.com"}
      end

      it "returns a validation failure" do
        result = service.accept_invite("code", invite.token)

        expect(result).not_to be_success
        expect(result.error.messages[:base]).to include("invite_email_mistmatch")
      end
    end

    context "when google auth is not set up" do
      before do
        ENV["GOOGLE_AUTH_CLIENT_ID"] = nil
        ENV["GOOGLE_AUTH_CLIENT_SECRET"] = nil
      end

      it "returns a service failure" do
        result = service.accept_invite("code", "FooBar")

        expect(result).not_to be_success
        expect(result.error.code).to eq("google_auth_missing_setup")
      end
    end
  end
end
