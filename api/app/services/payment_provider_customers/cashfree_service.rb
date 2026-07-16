# frozen_string_literal: true

module PaymentProviderCustomers
  class CashfreeService < BaseService
    include Customers::PaymentProviderFinder

    def initialize(cashfree_customer = nil)
      @cashfree_customer = cashfree_customer

      super(nil)
    end

    def create
      result.cashfree_customer = cashfree_customer
      result
    end

    def update
      result
    end

    def generate_checkout_url(send_webhook: true)
      result.not_allowed_failure!(code: "feature_not_supported")
    end

    private

    attr_accessor :cashfree_customer

    delegate :customer, to: :cashfree_customer
  end
end
