# frozen_string_literal: true

# This class represents a wallet credit and can be represented in credits or in an amount_cents
# Use this class when constructing wallet credits to make sure conversion between monetary amounts and credit amounts remains consistent
class WalletCredit
  # Convenience constructor for when you need to construct a credit based on monetary amounts
  def self.from_amount_cents(wallet:, amount_cents:)
    currency = wallet.currency_for_balance
    amount = amount_cents.round.fdiv(currency.subunit_to_unit)
    new(wallet:, credit_amount: amount.fdiv(wallet.rate_amount), amount_cents:)
  end

  def self.rounds_to_zero?(wallet:, credit_amount:)
    return false if credit_amount.blank?

    credit_amount = BigDecimal(credit_amount.to_s).floor(5)
    return false unless credit_amount.positive?

    new(wallet:, credit_amount:).amount_cents.zero?
  end

  # we'll assume you construct this normally for a wallet and a credit amount
  def initialize(wallet:, credit_amount:, invoiceable: true, amount_cents: nil)
    @wallet = wallet
    currency = wallet.currency_for_balance
    @amount = (credit_amount * wallet.rate_amount).round(currency.exponent)
    @amount_cents = (amount_cents || @amount * currency.subunit_to_unit).to_i

    @credit_amount = if invoiceable
      # Here we convert to amount andconvert back to credits
      # as we're talking about invoiceable credits. (only multiples of 1 cent should be accepted)
      amount.fdiv(wallet.rate_amount)
    else
      credit_amount
    end
  end

  attr_reader :wallet, :credit_amount, :amount, :amount_cents
end
