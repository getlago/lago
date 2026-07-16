# frozen_string_literal: true

module Clock
  class RefreshWalletsOngoingBalanceJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      return unless License.premium?

      scope = Customer.with_active_wallets.awaiting_wallet_refresh.without_tax_errors

      dedicated_org_ids = Utils::DedicatedWorkerConfig.organization_ids
      scope = scope.where.not(organization_id: dedicated_org_ids) if dedicated_org_ids.any?

      scope.find_each do |customer|
        Customers::RefreshWalletJob.perform_later(customer)
      end
    end
  end
end
