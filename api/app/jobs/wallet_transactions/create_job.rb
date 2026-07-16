# frozen_string_literal: true

module WalletTransactions
  class CreateJob < ApplicationJob
    queue_as "high_priority"
    unique :until_executed, on_conflict: :log

    # ActiveRecord::StaleObjectError is handled in WalletTransactions::CreateFromParamsService

    def perform(organization_id:, params:, unique_transaction: false)
      organization = Organization.find(organization_id)
      WalletTransactions::CreateFromParamsService.call!(organization:, params:)
    end

    # Override lock_key_arguments to conditionally include only relevant parameters
    # when uniqueness is needed (unique_transaction is true)
    def lock_key_arguments
      args = arguments[0].symbolize_keys
      org_id = args[:organization_id]
      params = args[:params]
      unique_transaction = args[:unique_transaction]

      if unique_transaction
        [
          org_id,
          params[:wallet_id],
          params[:paid_credits],
          params[:granted_credits]
        ]
      else
        # Return a unique value for each job to effectively disable uniqueness
        # when unique_transaction is false
        [SecureRandom.uuid]
      end
    end
  end
end
