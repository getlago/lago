# frozen_string_literal: true

module Resolvers
  module Analytics
    class InvoiceCollectionsResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "analytics:view"

      description "Query invoice collections of an organization"

      argument :billing_entity_code, String, required: false
      argument :billing_entity_id, ID, required: false
      argument :currency, Types::CurrencyEnum, required: false
      argument :is_customer_tin_empty, Boolean, required: false

      type Types::Analytics::InvoiceCollections::Object.collection_type, null: false

      def resolve(**args)
        raise unauthorized_error unless License.premium?

        ::Analytics::InvoiceCollection.find_all_by(current_organization.id, **args.merge(months: 12))
      end
    end
  end
end
