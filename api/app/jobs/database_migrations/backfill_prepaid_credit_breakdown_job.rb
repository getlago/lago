# frozen_string_literal: true

module DatabaseMigrations
  # Backfills `prepaid_granted_credit_amount_cents` and
  # `prepaid_purchased_credit_amount_cents` on invoices finalized before the
  # wallet credit breakdown feature shipped (https://github.com/getlago/lago-api/pull/5101).
  #
  # The values are aggregated from the historical `wallet_transaction_consumptions`
  # rows produced by `migrations:wallet_traceability`. No reconstruction happens
  # here — it applies the exact same rules as the live code
  # (Credits::AppliedPrepaidCreditsService#calculate_prepaid_credit_breakdown):
  #
  #   * granted   = consumed from `granted` inbound transactions
  #   * purchased = consumed from every other inbound transaction
  #   * a column is written only when its amount is > 0, otherwise left nil
  #   * only invoices whose customer is fully traceable are touched
  #     (mirrors `customer.wallets.all?(&:traceable?)`)
  class BackfillPrepaidCreditBreakdownJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 5_000
    GRANTED = WalletTransaction.transaction_statuses.fetch("granted")

    def perform(organization_id = nil, batch_number = 1)
      batch_ids = self.class.candidates(organization_id).limit(BATCH_SIZE).pluck(:id)

      if batch_ids.empty?
        Rails.logger.info("Finished backfilling prepaid credit breakdown")
        return
      end

      Invoice.where(id: batch_ids).update_all(UPDATE_ASSIGNMENTS) # rubocop:disable Rails/SkipsModelValidations
      self.class.perform_later(organization_id, batch_number + 1)
    end

    def lock_key_arguments
      [arguments]
    end

    # Invoices the live code would compute a breakdown for, not yet filled:
    #   * the invoice is settled (finalized or voided), not draft/failed/pending/etc.
    #   * prepaid credit was applied and the breakdown is empty
    #   * the customer is fully traceable
    #   * there are consumption rows to aggregate
    #   * those rows reconcile: total consumed == prepaid_credit_amount_cents.
    #     A mismatch means the consumption ledger is inconsistent for this invoice,
    #     so we skip it rather than write a wrong (and unbalanced) breakdown.
    def self.candidates(organization_id = nil)
      scope = Invoice
        .where(status: %i[finalized voided])
        .where(prepaid_granted_credit_amount_cents: nil, prepaid_purchased_credit_amount_cents: nil)
        .where("prepaid_credit_amount_cents > 0")
        .where.not(customer_id: Wallet.where(traceable: false).select(:customer_id))
        .where(id: consumed_invoice_ids)
        .where("prepaid_credit_amount_cents = (#{total_consumed_sql})")
      scope = scope.where(organization_id:) if organization_id
      scope
    end

    def self.pending_count(organization_id = nil)
      candidates(organization_id).count
    end

    # Invoice ids that have at least one outbound transaction with consumption rows.
    def self.consumed_invoice_ids
      WalletTransaction.outbound
        .where.not(invoice_id: nil)
        .where(id: WalletTransactionConsumption.select(:outbound_wallet_transaction_id))
        .select(:invoice_id)
    end

    # Total amount consumed across all of an invoice's outbound transactions —
    # used to verify the consumption ledger reconciles with prepaid_credit_amount_cents.
    def self.total_consumed_sql
      <<~SQL.squish
        SELECT COALESCE(SUM(c.consumed_amount_cents), 0)
        FROM wallet_transaction_consumptions c
        JOIN wallet_transactions out_wt ON out_wt.id = c.outbound_wallet_transaction_id
        WHERE out_wt.invoice_id = invoices.id
      SQL
    end

    # Set-based assignment: each column sums the consumed amount of its bucket for
    # the invoice, leaving the column nil when that bucket is zero.
    def self.bucket_sum_sql(operator)
      <<~SQL.squish
        NULLIF((
          SELECT COALESCE(SUM(c.consumed_amount_cents), 0)
          FROM wallet_transaction_consumptions c
          JOIN wallet_transactions out_wt ON out_wt.id = c.outbound_wallet_transaction_id
          JOIN wallet_transactions in_wt ON in_wt.id = c.inbound_wallet_transaction_id
          WHERE out_wt.invoice_id = invoices.id
            AND in_wt.transaction_status #{operator} #{GRANTED}
        ), 0)
      SQL
    end

    UPDATE_ASSIGNMENTS = [
      "prepaid_granted_credit_amount_cents = #{bucket_sum_sql("=")}",
      "prepaid_purchased_credit_amount_cents = #{bucket_sum_sql("<>")}"
    ].join(", ").freeze
  end
end
