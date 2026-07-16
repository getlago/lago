# frozen_string_literal: true

class MoneyHelper
  SYMBOLS_CURRENCIES = %w[$ € £ ¥].freeze
  DEFAULT_STUB_CURRENCY = "USD"

  def self.format(money)
    money&.format(
      format: currency_format(money&.currency),
      decimal_mark: I18n.t("money.decimal_mark"),
      thousands_separator: I18n.t("money.thousands_separator")
    )
  end

  def self.format_with_precision(amount_cents, currency)
    amount_cents = normalize_precision(amount_cents)
    money = Utils::MoneyWithPrecision.from_amount(amount_cents, currency)
    format(money)
  end

  def self.format_pricing_unit(amount_cents, currency)
    format_with_custom_currency(amount_cents, currency.short_name)
  end

  def self.format_pricing_unit_with_precision(amount_cents, currency)
    amount_cents = normalize_precision(amount_cents)
    format_with_custom_currency(amount_cents, currency.short_name)
  end

  def self.currency_format(money_currency)
    if SYMBOLS_CURRENCIES.include?(money_currency&.symbol)
      I18n.t("money.format")
    else
      I18n.t("money.custom_format", iso_code: money_currency&.iso_code)
    end
  end

  def self.normalize_precision(amount_cents)
    if amount_cents < 1
      BigDecimal("%.6g" % amount_cents)
    else
      amount_cents.round(6)
    end
  end

  def self.format_with_custom_currency(amount, currency_code)
    stub = Utils::MoneyWithPrecision.from_amount(amount, DEFAULT_STUB_CURRENCY)
    stub.format(
      format: "%n #{currency_code}",
      decimal_mark: I18n.t("money.decimal_mark"),
      thousands_separator: I18n.t("money.thousands_separator")
    )
  end
end
