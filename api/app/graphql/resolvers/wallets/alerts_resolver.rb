# frozen_string_literal: true

module Resolvers
  module Wallets
    class AlertsResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "wallets:update"

      description "Query alerts of a wallet"

      argument :wallet_id, String, required: true, description: "Id of a wallet"

      argument :limit, Integer, required: false
      argument :page, Integer, required: false

      type Types::UsageMonitoring::Alerts::Object.collection_type, null: false

      def resolve(wallet_id:, limit: nil, page: nil)
        ::UsageMonitoring::AlertsQuery.call(
          organization: current_organization,
          filters: {
            wallet_id:
          },
          pagination: {
            page:,
            limit:
          }
        ).alerts
      end
    end
  end
end
