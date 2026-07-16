# frozen_string_literal: true

module Mutations
  module Subscriptions
    module Alerts
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "subscriptions:update"

        graphql_name "UpdateSubscriptionAlert"
        description "Updates an alert"

        input_object_class Types::UsageMonitoring::Alerts::UpdateInput
        type Types::UsageMonitoring::Alerts::Object

        def resolve(**args)
          alert = current_organization.alerts.using_subscription.find_by(id: args[:id])

          result = ::UsageMonitoring::UpdateAlertService.call(
            alert:,
            params: args
          )

          result.success? ? result.alert : result_error(result)
        end
      end
    end
  end
end
