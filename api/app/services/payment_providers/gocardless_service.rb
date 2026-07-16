# frozen_string_literal: true

module PaymentProviders
  class GocardlessService < BaseService
    REDIRECT_URI = "#{ENV["LAGO_OAUTH_PROXY_URL"]}/gocardless/callback".freeze

    def create_or_update(**args)
      access_token = if args[:access_code].present?
        oauth.auth_code.get_token(args[:access_code], redirect_uri: REDIRECT_URI)&.token
      end

      payment_provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization].id,
        code: args[:code],
        id: args[:id],
        payment_provider_type: "gocardless"
      )

      gocardless_provider = if payment_provider_result.success?
        payment_provider_result.payment_provider
      else
        PaymentProviders::GocardlessProvider.new(
          organization_id: args[:organization].id,
          code: args[:code]
        )
      end

      old_code = gocardless_provider.code

      gocardless_provider.access_token = access_token if access_token
      gocardless_provider.webhook_secret = SecureRandom.alphanumeric(50) if gocardless_provider.webhook_secret.blank?
      gocardless_provider.success_redirect_url = args[:success_redirect_url] if args.key?(:success_redirect_url)
      gocardless_provider.code = args[:code] if args.key?(:code)
      gocardless_provider.name = args[:name] if args.key?(:name)
      gocardless_provider.save!

      if payment_provider_code_changed?(gocardless_provider, old_code, args)
        gocardless_provider.customers.update_all(payment_provider_code: args[:code]) # rubocop:disable Rails/SkipsModelValidations
      end

      result.gocardless_provider = gocardless_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue OAuth2::Error => e
      result.service_failure!(code: "internal_error", message: e.description)
    end

    private

    def oauth
      OAuth2::Client.new(
        ENV["GOCARDLESS_CLIENT_ID"],
        ENV["GOCARDLESS_CLIENT_SECRET"],
        site: PaymentProviders::GocardlessProvider.auth_site,
        authorize_url: "/oauth/authorize",
        token_url: "/oauth/access_token",
        auth_scheme: :request_body
      )
    end
  end
end
