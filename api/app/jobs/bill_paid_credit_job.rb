# frozen_string_literal: true

class BillPaidCreditJob < ApplicationJob
  queue_as "high_priority"

  retry_on Sequenced::SequenceError, wait: :polynomially_longer, attempts: 15, jitter: 0.75

  def perform(wallet_transaction, timestamp, invoice: nil)
    result = Invoices::PaidCreditService.call(
      wallet_transaction:,
      timestamp:,
      invoice:
    )
    return result if result.success?

    result.raise_if_error! if invoice || result.invoice.nil? || !result.invoice.generating?

    # NOTE: retry the job with the already created invoice in a previous failed attempt
    self.class.set(wait: 3.seconds).perform_later(
      wallet_transaction,
      timestamp,
      invoice: result.invoice
    )
  end
end
