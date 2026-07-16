# frozen_string_literal: true

FactoryBot.define do
  sequence :adyen_refunds_response do
    OpenStruct.new(
      response: {
        "merchantAccount" => SecureRandom.uuid,
        "pspReference" => SecureRandom.uuid,
        "paymentPspReference" => SecureRandom.uuid,
        "status" => "received",
        "amount" => {
          "currency" => "CHF",
          "value" => 134
        }
      }
    )
  end
end
