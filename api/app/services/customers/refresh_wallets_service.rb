# frozen_string_literal: true

module Customers
  class RefreshWalletsService < BaseService
    Result = BaseResult[:usage_amount_cents, :wallets, :allocation_rules]

    def initialize(customer:, include_generating_invoices: false, target_wallet_ids: nil)
      @customer = customer
      @include_generating_invoices = include_generating_invoices
      @target_wallet_ids = target_wallet_ids

      super
    end

    def call
      usage_amount_cents = customer.active_subscriptions.map do |subscription|
        invoice = ::Invoices::CustomerUsageService.call!(customer:, subscription:, usage_filters: UsageFilters::WITHOUT_PRESENTATION_FILTER).invoice

        billed_progressive_invoice_subscriptions = ::Subscriptions::ProgressiveBilledAmount
          .call(subscription:, include_generating_invoices:)
          .invoice_subscriptions

        {
          billed_progressive_invoice_subscriptions:,
          invoice:,
          subscription:
        }
      end

      @allocation_rules = Wallets::BuildAllocationRulesService.call!(customer:).allocation_rules

      # we need to get both: ALL fees and wallets_applicable_on_fees ({ fee_key => wallet_id, ... }) per each fee type
      # to not rebuild wallet assigning per each fee when going per each separate wallet
      usage_fees = usage_amount_cents.flat_map { |usage| usage[:invoice].fees }
      wallets_applicable_on_usage_fees = assign_wallet_per_fee(usage_fees) # { usage_fee_key => wallet_id }

      draft_invoice_fees = customer.invoices.draft.where.not(total_amount_cents: 0).includes(fees: :charge).flat_map(&:fees)
      wallets_applicable_on_draft_fees = assign_wallet_per_fee(draft_invoice_fees) # { draft_fee_key => wallet_id }

      progressive_billing_fees = usage_amount_cents.flat_map { |usage| usage[:billed_progressive_invoice_subscriptions].flat_map { it.invoice.fees } }
      wallets_applicable_on_pb_fees = assign_wallet_per_fee(progressive_billing_fees) # { pb_fee_key => wallet_id }

      pay_in_advance_fees = usage_amount_cents.flat_map { |usage| usage[:invoice].fees.select { |f| f.charge.pay_in_advance? } }
      wallets_applicable_on_adv_fees = assign_wallet_per_fee(pay_in_advance_fees) # { adv_fee_key => wallet_id }

      wallets_to_process = customer.wallets.active.includes(:recurring_transaction_rules)
      wallets_to_process = wallets_to_process.where(id: target_wallet_ids) if target_wallet_ids
      wallets_to_process.find_in_batches(batch_size: 100) do |wallets|
        wallets.each do |wallet|
          Wallets::Balance::RefreshOngoingUsageService.call!(
            wallet:,
            usage_amount_cents:,
            skip_single_wallet_update: true,
            current_usage_fees: applicable_fees(usage_fees, wallets_applicable_on_usage_fees, wallet),
            draft_invoices_fees: applicable_fees(draft_invoice_fees, wallets_applicable_on_draft_fees, wallet),
            progressive_billing_fees: applicable_fees(progressive_billing_fees, wallets_applicable_on_pb_fees, wallet),
            pay_in_advance_fees: applicable_fees(pay_in_advance_fees, wallets_applicable_on_adv_fees, wallet)
          )
        end
      end
      wallets_to_process.update_all(last_ongoing_balance_sync_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

      customer.update!(awaiting_wallet_refresh: false)

      result.usage_amount_cents = usage_amount_cents
      result.allocation_rules = allocation_rules
      result.wallets = customer.wallets.active.reload
      result
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :customer, :include_generating_invoices, :allocation_rules, :target_wallet_ids

    def assign_wallet_per_fee(fees)
      fee_wallet = {}
      fee_targeting_wallets_enabled = customer.organization.events_targeting_wallets_enabled?

      fees.each do |fee|
        key = fee.item_key

        if fee_targeting_wallets_enabled && fee.charge&.accepts_target_wallet && fee&.grouped_by&.dig("target_wallet_code").present?
          targeted_wallet = customer.wallets.active.where(code: fee.grouped_by["target_wallet_code"]).ids.first
          fee_wallet[key] = targeted_wallet
          next if targeted_wallet
        end

        applicable_wallets = Wallets::FindApplicableOnFeesService
          .call!(allocation_rules: allocation_rules, fee:, customer_id: customer.id, fee_targeting_wallets_enabled:)
          .top_priority_wallet
        fee_wallet[key] = applicable_wallets.presence
      end

      fee_wallet
    end

    def applicable_fees(fees, fee_map, wallet)
      fees.select { |fee| fee_map[fee.item_key] == wallet.id && fee.amount_currency == wallet.balance_currency }
    end
  end
end
