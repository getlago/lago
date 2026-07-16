# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ActivityLogs::ResourceTypeEnum do
  it "enumerates the correct values" do
    expect(described_class.values.keys).to match_array(
      %w[
        billable_metric
        plan
        customer
        invoice
        credit_note
        billing_entity
        subscription
        wallet
        coupon
        payment_request
        feature
        payment_receipt
      ]
    )
  end
end
