# frozen_string_literal: true

module Clock
  class CreateIntervalWalletTransactionsJob < ClockJob
    unique :until_executed, on_conflict: :log, lock_ttl: 4.hours

    def perform
      Wallets::CreateIntervalWalletTransactionsService.call
    end
  end
end
