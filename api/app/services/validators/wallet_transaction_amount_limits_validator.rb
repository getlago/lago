# frozen_string_literal: true

module Validators
  class WalletTransactionAmountLimitsValidator
    def initialize(result, wallet:, credits_amount:, ignore_validation: false, field_name: :paid_credits)
      @result = result
      @wallet = wallet
      # NOTE: credits_amount must be a string to be able to use ::Validators::DecimalAmountService
      @credits_amount = credits_amount
      @ignore_validation = ActiveModel::Type::Boolean.new.cast(ignore_validation)
      @field_name = field_name
    end

    def raise_if_invalid!
      return if valid?
      result.raise_if_error! # NOTE: if you didn't set the error in result, this won't raise if `valid?` is false
    end

    def valid?
      return false unless valid_paid_credits_amount?
      return true if ignore_validation
      return true if paid_top_up_min_amount_cents.blank? && paid_top_up_max_amount_cents.blank?

      wallet_credit = WalletCredit.new(
        wallet:,
        credit_amount: BigDecimal(credits_amount).floor(5)
      )

      if paid_top_up_min_amount_cents && wallet_credit.amount_cents < paid_top_up_min_amount_cents
        result.single_validation_failure!(error_code: "amount_below_minimum", field: field_name)
      elsif paid_top_up_max_amount_cents && wallet_credit.amount_cents > paid_top_up_max_amount_cents
        result.single_validation_failure!(error_code: "amount_above_maximum", field: field_name)
      end

      result.success?
    end

    private

    attr_reader :result, :wallet, :credits_amount, :ignore_validation, :field_name
    delegate :paid_top_up_min_amount_cents, :paid_top_up_max_amount_cents, to: :wallet

    def valid_paid_credits_amount?
      return true if ::Validators::DecimalAmountService.new(credits_amount).valid_positive_amount?

      result.single_validation_failure!(error_code: "invalid_amount", field: field_name)
      false
    end
  end
end
