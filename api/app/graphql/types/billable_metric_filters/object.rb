# frozen_string_literal: true

module Types
  module BillableMetricFilters
    class Object < BaseObject
      graphql_name "BillableMetricFilter"
      description "Billable metric filters"

      field :id, ID, null: false

      field :key, String, null: false
      field :values, [String], null: false

      def values
        object.values.sort
      end
    end
  end
end
