# frozen_string_literal: true

module Auth
  module Okta
    class BaseService < BaseService
      private

      def check_code
        raise ValidationError, "code_not_found" if code.blank?
      end

      def check_state
        raise ValidationError, "state_not_found" if state.blank?

        email = Rails.cache.read(state)
        raise ValidationError, "state_not_found" if email.blank?

        Rails.cache.delete(state)

        result.email = email
      end

      def check_okta_integration(email)
        email_domain = email.split("@").last
        okta_integration = ::Integrations::OktaIntegration
          .where("settings->>'domain' IS NOT NULL")
          .where("settings->>'domain' = ?", email_domain)
          .first

        raise ValidationError, "domain_not_configured" if okta_integration.blank?

        result.okta_integration = okta_integration
      end

      def check_invite(email)
        invite = Invite.pending.find_by(token: invite_token)

        raise ValidationError, "invite_not_found" if invite.blank?
        raise ValidationError, "invite_email_mismatch" if invite.email != email

        result.invite = invite
      end

      def query_okta_access_token
        params = {
          client_id: result.okta_integration.client_id,
          client_secret: result.okta_integration.client_secret,
          grant_type: "authorization_code",
          code:,
          redirect_uri: "#{ENV["LAGO_FRONT_URL"]}/auth/okta/callback"
        }

        token_client = LagoHttpClient::Client.new("https://#{result.okta_integration.host}/oauth2/v1/token")
        response = token_client.post_url_encoded(params, {})
        result.okta_access_token = response["access_token"]
      end

      def check_userinfo(email)
        userinfo_client = LagoHttpClient::Client.new("https://#{result.okta_integration.host}/oauth2/v1/userinfo")
        userinfo_headers = {"Authorization" => "Bearer #{result.okta_access_token}"}
        response = userinfo_client.get(headers: userinfo_headers)

        raise ValidationError, "okta_userinfo_error" if response["email"] != email

        result.userinfo = response
      end
    end

    class ValidationError < StandardError; end
  end
end
