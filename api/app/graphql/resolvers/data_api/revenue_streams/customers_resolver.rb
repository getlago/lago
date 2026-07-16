# frozen_string_literal: true

module Resolvers
  module DataApi
    module RevenueStreams
      class CustomersResolver < Resolvers::BaseResolver
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "data_api:view"

        graphql_name "DataApiRevenueStreamsCustomers"
        description "Query revenue streams customers of an organization"

        argument :currency, Types::CurrencyEnum, required: false
        argument :limit, Integer, required: false
        argument :order_by, Types::DataApi::RevenueStreams::OrderByEnum, required: false
        argument :page, Integer, required: false

        type Types::DataApi::RevenueStreams::Customers::Collection, null: false

        def resolve(**args)
          result = ::DataApi::RevenueStreams::CustomersService.call(current_organization, **args)

          {
            collection: result.data_revenue_streams_customers["revenue_streams_customers"],
            metadata: result.data_revenue_streams_customers["meta"]
          }
        end
      end
    end
  end
end
