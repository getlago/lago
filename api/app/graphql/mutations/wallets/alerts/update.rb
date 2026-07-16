# frozen_string_literal: true

module Mutations
  module Wallets
    module Alerts
      class Update < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "wallets:update"

        graphql_name "UpdateCustomerWalletAlert"
        description "Updates an alert"

        input_object_class Types::UsageMonitoring::Alerts::UpdateInput
        type Types::UsageMonitoring::Alerts::Object

        def resolve(**args)
          alert = current_organization.alerts.using_wallet.find_by(id: args[:id])

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
