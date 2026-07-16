# frozen_string_literal: true

module PaymentMethods
  class DestroyService < BaseService
    def initialize(payment_method:)
      @payment_method = payment_method

      super
    end

    def call
      return result.not_found_failure!(resource: "payment_method") unless payment_method

      payment_method.is_default = false
      payment_method.discard!

      result.payment_method = payment_method
      result
    end

    private

    attr_reader :payment_method
  end
end
