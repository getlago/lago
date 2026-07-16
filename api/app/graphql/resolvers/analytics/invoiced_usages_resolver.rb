# frozen_string_literal: true

module Resolvers
  module Analytics
    class InvoicedUsagesResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "analytics:view"

      description "Query invoiced usage of an organization"

      argument :billing_entity_id, ID, required: false
      argument :currency, Types::CurrencyEnum, required: false

      type Types::Analytics::InvoicedUsages::Object.collection_type, null: false

      def resolve(**args)
        raise unauthorized_error unless License.premium?

        ::Analytics::InvoicedUsage.find_all_by(current_organization.id, **args.merge({months: 12}))
      end
    end
  end
end
