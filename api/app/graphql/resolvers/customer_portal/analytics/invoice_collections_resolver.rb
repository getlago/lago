# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    module Analytics
      class InvoiceCollectionsResolver < Resolvers::BaseResolver
        include AuthenticableCustomerPortalUser

        description "Query invoice collections of a customer portal user"

        argument :months, Integer, required: false

        argument :expire_cache, Boolean, required: false

        type Types::Analytics::InvoiceCollections::Object.collection_type, null: false

        def resolve(**args)
          ::Analytics::InvoiceCollection.find_all_by(
            context[:customer_portal_user].organization.id,
            **args.merge(
              currency: context[:customer_portal_user].currency,
              external_customer_id: context[:customer_portal_user].external_id
            )
          )
        end
      end
    end
  end
end
