# frozen_string_literal: true

module WalletTransactions
  module Payments
    class GeneratePaymentUrlService < BaseService
      Result = BaseResult

      def initialize(wallet_transaction:)
        @wallet_transaction = wallet_transaction
        super
      end

      def call
        return result.not_found_failure!(resource: "wallet_transaction") unless wallet_transaction

        unless wallet_transaction.purchased?
          return result.single_validation_failure!(error_code: "wallet_transaction_not_purchased")
        end

        if wallet_transaction.settled?
          return result.single_validation_failure!(error_code: "wallet_transaction_already_settled")
        end

        unless invoice
          return result.single_validation_failure!(error_code: "wallet_transaction_has_no_attached_invoice")
        end

        ::Invoices::Payments::GeneratePaymentUrlService.call(invoice:)
      end

      private

      attr_reader :wallet_transaction

      delegate :invoice, to: :wallet_transaction, allow_nil: true
    end
  end
end
