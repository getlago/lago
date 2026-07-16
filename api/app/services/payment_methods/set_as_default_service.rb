# frozen_string_literal: true

module PaymentMethods
  class SetAsDefaultService < BaseService
    Result = BaseResult[:payment_method]

    def initialize(payment_method:)
      @payment_method = payment_method

      super
    end

    def call
      return result.not_found_failure!(resource: "payment_method") unless payment_method
      if payment_method.is_default?
        result.payment_method = payment_method
        return result
      end

      ActiveRecord::Base.transaction do
        payment_method.customer.payment_methods.where.not(id: payment_method.id).update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
        payment_method.update!(is_default: true)
      end

      result.payment_method = payment_method

      result
    end

    private

    attr_reader :payment_method
  end
end
