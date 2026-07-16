# frozen_string_literal: true

module Resolvers
  module Wallets
    class AlertResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "wallets:update"

      description "Query a single wallet alert"

      argument :id, ID, required: true, description: "Unique ID of the alert"

      type Types::UsageMonitoring::Alerts::Object, null: true

      def resolve(id:)
        current_organization.alerts.using_wallet.find(id)
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "alert")
      end
    end
  end
end
