# frozen_string_literal: true

RSpec::Matchers.define :have_empty_charge_fees do
  match do |invoice|
    invoice.fees.charge.all? do |fee|
      from = Time.zone.parse(fee.properties["charges_from_datetime"])
      to = Time.zone.parse(fee.properties["charges_to_datetime"])

      fee.total_amount_cents.zero? && from.before?(to)
    end
  end

  failure_message do |invoice|
    "expected that #{invoice} would have empty charge fees but fees were found.\n" \
      "Fees: #{invoice.fees.charge.all.map(&:total_amount_cents)}"
  end

  failure_message_when_negated do |invoice|
    "expected that #{invoice} would have some charge fees but none were found.\n" \
      "Fees: #{invoice.fees.charge.all.map(&:total_amount_cents)}"
  end
end
