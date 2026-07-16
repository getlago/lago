# frozen_string_literal: true

module Wallets
  module Balance
    class RefreshOngoingUsageService < BaseService
      Result = BaseResult[:wallet]

      def initialize(wallet:, usage_amount_cents:, current_usage_fees:, draft_invoices_fees:, progressive_billing_fees:, pay_in_advance_fees:, skip_single_wallet_update: false)
        @wallet = wallet
        @usage_amount_cents = usage_amount_cents
        @skip_single_wallet_update = skip_single_wallet_update
        @current_usage_fees = current_usage_fees
        @draft_invoices_fees = draft_invoices_fees
        @progressive_billing_fees = progressive_billing_fees
        @pay_in_advance_fees = pay_in_advance_fees

        super
      end

      def call
        @total_usage_amount_cents = calculate_total_usage_with_limitation
        @total_billed_usage_amount_cents = calculate_total_billed_usage_amount_cents

        # Before this service is called, the wallet is already loaded in the memory. If while calculating current usage we received
        # a pay_in_advance_fee, wallet will be updated by Wallets::Balance::DecreaseService and current wallet version will throw an
        # `Attempted to update a stale object` error. To avoid this, we reload the wallet before updating it.
        wallet.reload
        update_params = wallet_update_params

        Wallets::Balance::UpdateOngoingService.call(wallet:, update_params:, skip_single_wallet_update:).raise_if_error!

        result.wallet = wallet
        result
      end

      private

      attr_reader :wallet, :total_usage_amount_cents, :total_billed_usage_amount_cents, :usage_amount_cents, :skip_single_wallet_update,
        :current_usage_fees, :draft_invoices_fees, :progressive_billing_fees, :pay_in_advance_fees

      delegate :customer, to: :wallet

      def calculate_total_billed_usage_amount_cents
        billed_progressive_invoices_amount_cents +
          billed_pay_in_advance_amount_cents
      end

      def billed_progressive_invoices_amount_cents
        progressive_billing_fees.sum do |fee|
          fee.taxes_amount_cents + fee.sub_total_excluding_taxes_amount_cents
        end
      end

      def draft_invoices_total_amount_cents
        draft_invoices_fees.sum do |fee|
          fee.amount_cents + fee.taxes_amount_cents - fee.precise_coupons_amount_cents
        end
      end

      def billed_pay_in_advance_amount_cents
        # Invoice that is returned from CustomerUsageService includes the taxes in total_usage
        # so if the fees ae already paid, we should exclude fees AND their taxes
        pay_in_advance_fees.sum { |fee| fee.amount_cents + fee.taxes_amount_cents }
      end

      def calculate_total_usage_with_limitation
        current_usage_fees.sum { |fee| fee.amount_cents + fee.taxes_amount_cents }
      end

      def wallet_update_params
        params = {
          ongoing_usage_balance_cents:,
          credits_ongoing_usage_balance:,
          ongoing_balance_cents:,
          credits_ongoing_balance:
        }

        if !wallet.depleted_ongoing_balance? && ongoing_balance_cents <= 0
          params[:depleted_ongoing_balance] = true
        elsif wallet.depleted_ongoing_balance? && ongoing_balance_cents.positive?
          params[:depleted_ongoing_balance] = false
        end

        params
      end

      def currency
        @currency ||= wallet.ongoing_balance.currency
      end

      def ongoing_usage_balance_cents
        @ongoing_usage_balance_cents ||= total_usage_amount_cents +
          draft_invoices_total_amount_cents -
          total_billed_usage_amount_cents
      end

      def credits_ongoing_usage_balance
        ongoing_usage_balance_cents.to_f.fdiv(currency.subunit_to_unit).fdiv(wallet.rate_amount)
      end

      def ongoing_balance_cents
        @ongoing_balance_cents ||= wallet.balance_cents - ongoing_usage_balance_cents
      end

      def credits_ongoing_balance
        ongoing_balance_cents.to_f.fdiv(currency.subunit_to_unit).fdiv(wallet.rate_amount)
      end
    end
  end
end
