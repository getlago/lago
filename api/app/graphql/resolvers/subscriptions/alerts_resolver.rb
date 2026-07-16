# frozen_string_literal: true

module Resolvers
  module Subscriptions
    class AlertsResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:view"

      description "Query alerts of a subscription"

      # extras [:lookahead]

      argument :subscription_external_id, String, required: true, description: "External id of a subscription"

      argument :limit, Integer, required: false
      argument :page, Integer, required: false

      type Types::UsageMonitoring::Alerts::Object.collection_type, null: false

      def resolve(subscription_external_id:, limit: nil, page: nil)
        ::UsageMonitoring::AlertsQuery.call(
          organization: current_organization,
          filters: {
            subscription_external_id:
          },
          pagination: {
            page:,
            limit:
          }
        ).alerts

        # if lookahead.selection(:collection).selects?(:thresholds)
        #   alerts_query = alerts_query.includes(:thresholds)
        # end
        #
        # if lookahead.selection(:collection).selects?(:billable_metric)
        #   alerts_query = alerts_query.includes(:billable_metric)
        # end
      end
    end
  end
end
