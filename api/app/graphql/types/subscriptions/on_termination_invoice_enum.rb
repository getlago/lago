# frozen_string_literal: true

module Types
  module Subscriptions
    class OnTerminationInvoiceEnum < Types::BaseEnum
      Subscription::ON_TERMINATION_INVOICES.each_key do |action|
        value action
      end
    end
  end
end
