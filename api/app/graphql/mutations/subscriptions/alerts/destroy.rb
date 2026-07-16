# frozen_string_literal: true

module Mutations
  module Subscriptions
    module Alerts
      class Destroy < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "subscriptions:update"

        graphql_name "DestroySubscriptionAlert"
        description "Deletes an alert"

        argument :id, ID, required: true

        type Types::UsageMonitoring::Alerts::Object

        def resolve(**args)
          alert = current_organization.alerts.using_subscription.find_by(id: args[:id])
          result = ::UsageMonitoring::DestroyAlertService.call(alert:)

          result.success? ? result.alert : result_error(result)
        end
      end
    end
  end
end
