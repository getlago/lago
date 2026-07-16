# frozen_string_literal: true

module Resolvers
  class CustomersResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "customers:view"

    description "Query customers of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false

    argument :search_term, String, required: false

    argument :account_type, [Types::Customers::AccountTypeEnum], required: false
    argument :active_subscriptions_count_from, Integer, required: false
    argument :active_subscriptions_count_to, Integer, required: false
    argument :billing_entity_ids, [ID], required: false
    argument :countries, [Types::CountryCodeEnum], required: false
    argument :currencies, [Types::CurrencyEnum], required: false
    argument :customer_type, Types::Customers::CustomerTypeEnum, required: false
    argument :external_id, String, required: false
    argument :has_customer_type, Boolean, required: false
    argument :has_tax_identification_number, Boolean, required: false
    argument :metadata, [Types::Customers::Metadata::Filter], required: false
    argument :states, [String], required: false
    argument :with_deleted, Boolean, required: false
    argument :zipcodes, [String], required: false

    type Types::Customers::Object.collection_type, null: false

    def resolve(search_term: nil, page: nil, limit: nil, metadata: nil, **filters)
      if metadata.present?
        filters[:metadata] = metadata.to_h { |m| [m[:key], m[:value]] }
      end
      result = CustomersQuery.call(
        organization: current_organization,
        search_term:,
        pagination: {
          page:,
          limit:
        },
        filters:
      )

      result.customers.preload(
        :billing_entity,
        :metadata,
        :anrok_customer,
        :avalara_customer,
        :hubspot_customer,
        :netsuite_customer,
        :salesforce_customer,
        :xero_customer
      )
    end
  end
end
