# frozen_string_literal: true

module Resolvers
  module DataApi
    module RevenueStreams
      class PlansResolver < Resolvers::BaseResolver
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "data_api:view"

        graphql_name "DataApiRevenueStreamsPlans"
        description "Query revenue streams plans of an organization"

        argument :currency, Types::CurrencyEnum, required: false
        argument :limit, Integer, required: false
        argument :order_by, Types::DataApi::RevenueStreams::OrderByEnum, required: false
        argument :page, Integer, required: false

        type Types::DataApi::RevenueStreams::Plans::Collection, null: false

        def resolve(**args)
          result = ::DataApi::RevenueStreams::PlansService.call(current_organization, **args)

          {
            collection: result.data_revenue_streams_plans["revenue_streams_plans"],
            metadata: result.data_revenue_streams_plans["meta"]
          }
        end
      end
    end
  end
end
