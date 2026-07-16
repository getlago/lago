# frozen_string_literal: true

module Types
  module Wallets
    class Metadata < GraphqlPagination::CollectionMetadataType
      graphql_name "WalletCollectionMetadata"
      field :customer_active_wallets_count, Integer, null: false

      def customer_active_wallets_count
        return 0 if object.empty?

        object.first.customer.wallets.active.count
      end
    end
  end
end
