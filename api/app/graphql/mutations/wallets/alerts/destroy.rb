# frozen_string_literal: true

module Mutations
  module Wallets
    module Alerts
      class Destroy < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "wallets:update"

        graphql_name "DestroyCustomerWalletAlert"
        description "Deletes an alert"

        argument :id, ID, required: true

        type Types::UsageMonitoring::Alerts::Object

        def resolve(**args)
          alert = current_organization.alerts.using_wallet.find_by(id: args[:id])
          result = ::UsageMonitoring::DestroyAlertService.call(alert:)

          result.success? ? result.alert : result_error(result)
        end
      end
    end
  end
end
