# frozen_string_literal: true

module Mutations
  module Wallets
    module Alerts
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "wallets:update"

        graphql_name "CreateCustomerWalletAlert"
        description "Creates a new Alert for wallet"

        input_object_class Types::UsageMonitoring::Alerts::CreateInput
        argument :wallet_id, ID, required: true

        type Types::UsageMonitoring::Alerts::Object

        def resolve(**args)
          result = ::UsageMonitoring::CreateAlertService.call(
            organization: current_organization,
            alertable: current_organization.wallets.find(args[:wallet_id]),
            params: args
          )

          result.success? ? result.alert : result_error(result)
        end
      end
    end
  end
end
