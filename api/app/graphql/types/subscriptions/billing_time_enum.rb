# frozen_string_literal: true

module Types
  module Subscriptions
    class BillingTimeEnum < Types::BaseEnum
      Subscription::BILLING_TIME.each do |type|
        value type
      end
    end
  end
end
