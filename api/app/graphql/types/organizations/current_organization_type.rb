# frozen_string_literal: true

module Types
  module Organizations
    class CurrentOrganizationType < BaseOrganizationType
      description "Current Organization Type"

      field :id, ID, null: false
      field :logo_url, String
      field :name, String, null: false
      field :slug, String, null: false
      field :timezone, Types::TimezoneEnum

      field :default_currency, Types::CurrencyEnum, null: false
      field :email, String

      field :legal_name, String
      field :legal_number, String
      field :tax_identification_number, String

      field :address_line1, String
      field :address_line2, String
      field :city, String
      field :country, Types::CountryCodeEnum
      field :net_payment_term, Integer, null: false
      field :state, String
      field :zipcode, String

      field :api_key, String, permission: "developers:keys:manage"
      field :hmac_key, String, permission: "developers:keys:manage"
      field :webhook_url, String, permission: "developers:manage"

      field :document_number_prefix, String, null: false
      field :document_numbering, Types::Organizations::DocumentNumberingEnum, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :eu_tax_management, Boolean, null: false

      field :events_store, Types::Organizations::EventsStoreEnum, null: false

      # TODO: Also check if Nango ENV var is set in order to lock/unlock this feature
      #       This would enable us to use premium add_on logic on OSS version
      field :premium_integrations, [Types::Integrations::PremiumIntegrationTypeEnum], null: false

      field :feature_flags, [Types::Organizations::FeatureFlagEnum], null: false

      field :billing_configuration, Types::Organizations::BillingConfiguration, permission: "organization:invoices:view"
      field :email_settings, [Types::Organizations::EmailSettingsEnum], permission: "organization:emails:view"
      field :finalize_zero_amount_invoice, Boolean, null: false
      field :taxes, [Types::Taxes::Object], resolver: Resolvers::TaxesResolver, permission: "organization:taxes:view"

      field :adyen_payment_providers, [Types::PaymentProviders::Adyen], permission: "organization:integrations:view"
      field :cashfree_payment_providers, [Types::PaymentProviders::Cashfree], permission: "organization:integrations:view"
      field :gocardless_payment_providers, [Types::PaymentProviders::Gocardless], permission: "organization:integrations:view"
      field :stripe_payment_providers, [Types::PaymentProviders::Stripe], permission: "organization:integrations:view"

      field :applied_dunning_campaign, Types::DunningCampaigns::Object
      field :can_create_billing_entity, Boolean, null: false, method: :can_create_billing_entity?

      field :accessible_by_current_session, Boolean, null: false
      field :authenticated_method, Types::Organizations::AuthenticationMethodsEnum, null: false
      field :authentication_methods, [Types::Organizations::AuthenticationMethodsEnum], null: false

      def feature_flags
        object.feature_flags.select { |flag| FeatureFlag.valid?(flag) }
      end

      def webhook_url
        object.webhook_endpoints.map(&:webhook_url).first
      end

      def api_key
        object.api_keys.first.value
      end

      def accessible_by_current_session
        object.authentication_methods.include?(context[:login_method])
      end

      def authenticated_method
        context[:login_method]
      end
    end
  end
end
