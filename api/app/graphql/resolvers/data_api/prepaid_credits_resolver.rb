# frozen_string_literal: true

module Resolvers
  module DataApi
    class PrepaidCreditsResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "data_api:view"

      graphql_name "DataApiPrepaidCredits"
      description "Query prepaid credits of an organization"

      argument :currency, Types::CurrencyEnum, required: false

      argument :customer_country, Types::CountryCodeEnum, required: false
      argument :customer_type, Types::Customers::CustomerTypeEnum, required: false

      argument :from_date, GraphQL::Types::ISO8601Date, required: false
      argument :to_date, GraphQL::Types::ISO8601Date, required: false

      argument :time_granularity, Types::DataApi::TimeGranularityEnum, required: false

      argument :external_customer_id, String, required: false
      argument :external_subscription_id, String, required: false

      argument :billing_entity_code, String, required: false
      argument :plan_code, String, required: false

      argument :is_customer_tin_empty, Boolean, required: false

      type Types::DataApi::PrepaidCredits::Object.collection_type, null: false

      def resolve(**args)
        result = ::DataApi::PrepaidCreditsService.call(current_organization, **args)
        result.prepaid_credits
      end
    end
  end
end
