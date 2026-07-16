# frozen_string_literal: true

module Resolvers
  module Analytics
    class OverdueBalancesResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "analytics:view"

      description "Query overdue balances of an organization"

      argument :billing_entity_code, String, required: false
      argument :billing_entity_id, ID, required: false
      argument :currency, Types::CurrencyEnum, required: false
      argument :external_customer_id, String, required: false
      argument :is_customer_tin_empty, Boolean, required: false
      argument :months, Integer, required: false

      argument :expire_cache, Boolean, required: false

      type Types::Analytics::OverdueBalances::Object.collection_type, null: false

      def resolve(**args)
        ::Analytics::OverdueBalance.find_all_by(current_organization.id, **args)
      end
    end
  end
end
