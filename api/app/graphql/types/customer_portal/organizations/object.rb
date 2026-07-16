# frozen_string_literal: true

module Types
  module CustomerPortal
    module Organizations
      class Object < Types::Organizations::BaseOrganizationType
        graphql_name "CustomerPortalOrganization"
        description "CustomerPortalOrganization"

        field :id, ID, null: false

        field :billing_configuration, Types::Organizations::BillingConfiguration, null: true
        field :default_currency, Types::CurrencyEnum, null: false
        field :logo_url, String
        field :name, String, null: false
        field :premium_integrations, [Types::Integrations::PremiumIntegrationTypeEnum], null: false
        field :timezone, Types::TimezoneEnum, null: true
      end
    end
  end
end
