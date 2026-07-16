# frozen_string_literal: true

module Clock
  class RefreshDedicatedOrgWalletsOngoingBalanceJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      return unless License.premium?

      org_ids = Utils::DedicatedWorkerConfig.organization_ids
      return if org_ids.empty?

      Customer
        .where(organization_id: org_ids)
        .with_active_wallets
        .awaiting_wallet_refresh
        .without_tax_errors
        .find_each do |customer|
          Customers::RefreshWalletJob.perform_later(customer)
        end
    end
  end
end
