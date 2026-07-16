# frozen_string_literal: true

module Resolvers
  module Analytics
    class GrossRevenuesResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "analytics:view"

      description "Query gross revenue of an organization"

      argument :billing_entity_id, ID, required: false
      argument :currency, Types::CurrencyEnum, required: false
      argument :external_customer_id, String, required: false
      argument :months, Integer, required: false

      argument :expire_cache, Boolean, required: false

      type Types::Analytics::GrossRevenues::Object.collection_type, null: false

      def resolve(**args)
        ::Analytics::GrossRevenue.find_all_by(current_organization.id, **args)
      end
    end
  end
end
