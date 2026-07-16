# frozen_string_literal: true

module Resolvers
  class BillableMetricsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "billable_metrics:view"

    description "Query billable metrics of an organization"

    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :recurring, Boolean, required: false
    argument :search_term, String, required: false

    argument :aggregation_types, [Types::BillableMetrics::AggregationTypeEnum], required: false
    argument :plan_id, ID, required: false

    type Types::BillableMetrics::Object.collection_type, null: false

    def resolve(**args)
      result = ::BillableMetricsQuery.call(
        organization: current_organization,
        search_term: args[:search_term],
        pagination: {page: args[:page], limit: args[:limit]},
        filters: args.slice(:recurring, :aggregation_types, :plan_id)
      )

      result.billable_metrics
    end
  end
end
