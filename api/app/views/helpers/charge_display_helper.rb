# frozen_string_literal: true

class ChargeDisplayHelper
  def self.format_min_amount(charge)
    if charge.applied_pricing_unit
      MoneyHelper.format_pricing_unit(
        charge.min_amount_cents.to_d / 100,
        charge.pricing_unit
      )
    else
      money = Money.from_cents(charge.min_amount_cents, charge.plan.amount.currency)
      MoneyHelper.format(money)
    end
  end
end
