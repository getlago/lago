# frozen_string_literal: true

module PaymentProviderCustomers
  class FlutterwaveService < BaseService
    include Customers::PaymentProviderFinder

    def initialize(flutterwave_customer = nil)
      @flutterwave_customer = flutterwave_customer

      super(nil)
    end

    def create
      result.flutterwave_customer = flutterwave_customer
      result
    end

    def update
      result
    end

    def generate_checkout_url(send_webhook: true)
      result.not_allowed_failure!(code: "feature_not_supported")
    end

    private

    attr_accessor :flutterwave_customer

    delegate :customer, to: :flutterwave_customer
  end
end
