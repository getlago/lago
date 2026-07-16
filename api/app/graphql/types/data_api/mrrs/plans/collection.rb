# frozen_string_literal: true

module Types
  module DataApi
    module Mrrs
      module Plans
        class Collection < Types::BaseObject
          graphql_name "DataApiMrrsPlans"

          field :collection, [Types::DataApi::Mrrs::Plans::Object], null: false

          field :metadata, Types::DataApi::Metadata, null: false
        end
      end
    end
  end
end
