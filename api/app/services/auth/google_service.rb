# frozen_string_literal: true

module Auth
  class GoogleService < BaseService
    BASE_SCOPE = %w[profile email openid].freeze

    def authorize_url(request)
      ensure_google_auth_setup
      return result unless result.success?

      authorizer = Google::Auth::WebUserAuthorizer.new(
        client_id,
        BASE_SCOPE,
        nil, # token_store is nil because we don't need to store the token
        "#{ENV["LAGO_FRONT_URL"]}/auth/google/callback"
      )

      result.url = authorizer.get_authorization_url(request:)

      result
    end

    def login(code)
      ensure_google_auth_setup
      return result unless result.success?

      google_oidc = oidc_verifier(code:)
      user = User.find_by(email: google_oidc["email"])

      unless user.present? && user.memberships&.active&.any?
        return result.single_validation_failure!(error_code: "user_does_not_exist")
      end

      unless user.active_organizations.pluck(:authentication_methods).flatten.uniq.include?(Organizations::AuthenticationMethods::GOOGLE_OAUTH)
        return result.single_validation_failure!(
          error_code: "login_method_not_authorized",
          field: Organizations::AuthenticationMethods::GOOGLE_OAUTH
        )
      end

      result.user = user
      UserDevices::RegisterService.call!(user:)
      generate_token
    rescue Google::Auth::IDTokens::SignatureError
      result.single_validation_failure!(error_code: "invalid_google_token")
    rescue Signet::AuthorizationError
      result.single_validation_failure!(error_code: "invalid_google_code")
    end

    def register_user(code, organization_name)
      ensure_google_auth_setup
      return result unless result.success?

      google_oidc = oidc_verifier(code:)

      register(google_oidc["email"], organization_name)
    rescue Google::Auth::IDTokens::SignatureError
      result.single_validation_failure!(error_code: "invalid_google_token")
    rescue Signet::AuthorizationError
      result.single_validation_failure!(error_code: "invalid_google_code")
    end

    def accept_invite(code, invite_token)
      ensure_google_auth_setup
      return result unless result.success?

      google_oidc = oidc_verifier(code:)
      invite = Invite.find_by(token: invite_token, status: :pending)

      return result.not_found_failure!(resource: "invite") unless invite

      unless google_oidc["email"] == invite.email
        return result.single_validation_failure!(error_code: "invite_email_mistmatch")
      end

      Invites::AcceptService.new.call(
        invite:,
        email: google_oidc["email"],
        token: invite_token,
        password: SecureRandom.hex,
        login_method: Organizations::AuthenticationMethods::GOOGLE_OAUTH
      )
    rescue Google::Auth::IDTokens::SignatureError
      result.single_validation_failure!(error_code: "invalid_google_token")
    rescue Signet::AuthorizationError
      result.single_validation_failure!(error_code: "invalid_google_code")
    end

    private

    def generate_token
      result.token = Auth::TokenService.encode(user: result.user, login_method: Organizations::AuthenticationMethods::GOOGLE_OAUTH)
      result
    rescue => e
      result.service_failure!(code: "token_encoding_error", message: e.message)
    end

    def register(email, organization_name)
      if ENV.fetch("LAGO_DISABLE_SIGNUP", "false") == "true"
        return result.not_allowed_failure!(code: "signup_disabled")
      end

      if User.exists?(email:)
        result.single_validation_failure!(field: :email, error_code: "user_already_exists")

        return result
      end

      ActiveRecord::Base.transaction do
        result.user = User.create!(email:, password: SecureRandom.hex)

        result.organization = Organizations::CreateService
          .call!(name: organization_name, document_numbering: "per_organization")
          .organization

        result.membership = Membership.create!(
          user: result.user,
          organization: result.organization
        )

        role = Role.find_by!(admin: true)
        MembershipRole.create!(membership: result.membership, organization: result.organization, role:)

        generate_token
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      SegmentIdentifyJob.perform_later(membership_id: "membership/#{result.membership.id}")
      track_organization_registered(result.organization, result.membership)

      # Skip log: user.signed_up already covers signup
      UserDevices::RegisterService.call!(user: result.user, skip_log: true)

      result
    end

    def track_organization_registered(organization, membership)
      SegmentTrackJob.perform_later(
        membership_id: "membership/#{membership.id}",
        event: "organization_registered",
        properties: {
          organization_name: organization.name,
          organization_id: organization.id,
          email: membership.user.email
        }
      )
    end

    def client_id
      @client_id ||= Google::Auth::ClientId.new(ENV["GOOGLE_AUTH_CLIENT_ID"], ENV["GOOGLE_AUTH_CLIENT_SECRET"])
    end

    def ensure_google_auth_setup
      return if ENV["GOOGLE_AUTH_CLIENT_ID"].present? && ENV["GOOGLE_AUTH_CLIENT_SECRET"].present?

      result.service_failure!(code: "google_auth_missing_setup", message: "Google auth is not set up")
    end

    def oidc_verifier(code:)
      authorizer = Google::Auth::UserAuthorizer.new(
        client_id,
        BASE_SCOPE,
        nil, # token_store is nil because we don't need to store the token
        "#{ENV["LAGO_FRONT_URL"]}/auth/google/callback"
      )

      credentials = authorizer.get_credentials_from_code(code:)
      Google::Auth::IDTokens.verify_oidc(credentials.id_token, aud: ENV["GOOGLE_AUTH_CLIENT_ID"])
    end
  end
end
