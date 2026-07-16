# frozen_string_literal: true

module Resolvers
  module DataApi
    module Mrrs
      class PlansResolver < Resolvers::BaseResolver
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "data_api:view"

        graphql_name "DataApiMrrsPlans"
        description "Query monthly recurring revenues plans of an organization"

        argument :currency, Types::CurrencyEnum, required: false
        argument :limit, Integer, required: false
        argument :page, Integer, required: false

        type Types::DataApi::Mrrs::Plans::Collection, null: false

        def resolve(**args)
          result = ::DataApi::Mrrs::PlansService.call(current_organization, **args)

          {
            collection: result.data_mrrs_plans["mrrs_plans"],
            metadata: result.data_mrrs_plans["meta"]
          }
        end
      end
    end
  end
end
