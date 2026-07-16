# frozen_string_literal: true

module PaymentMethods
  CardDetails = Data.define(
    :type,
    :last4,
    :brand,
    :expiration_month,
    :expiration_year,
    :card_holder_name,
    :issuer
  ) do
    def to_h
      super.compact
    end
  end
end
