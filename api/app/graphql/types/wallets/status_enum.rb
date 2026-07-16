# frozen_string_literal: true

module Types
  module Wallets
    class StatusEnum < Types::BaseEnum
      graphql_name "WalletStatusEnum"

      Wallet::STATUSES.each do |type|
        value type
      end
    end
  end
end
