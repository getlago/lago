# frozen_string_literal: true

module Resolvers
  module Subscriptions
    class AlertResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:view"

      description "Query a single subscription alert"

      argument :id, ID, required: true, description: "Unique ID of the alert"

      type Types::UsageMonitoring::Alerts::Object, null: true

      def resolve(id:)
        current_organization.alerts.using_subscription.find(id)
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "alert")
      end
    end
  end
end
