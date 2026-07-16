# frozen_string_literal: true

module PaymentMethods
  class UpdateDetailsService < BaseService
    def initialize(payment_method:, insert: {}, delete: {})
      @payment_method = payment_method
      @insert = insert.with_indifferent_access
      @delete = delete.with_indifferent_access

      super
    end

    def call
      return result.not_found_failure!(resource: "payment_method") unless payment_method

      payment_method.details.merge!(insert)
      payment_method.details.except!(*delete.keys)

      payment_method.save!

      result.payment_method = payment_method
      result
    end

    private

    attr_accessor :payment_method, :insert, :delete
  end
end
