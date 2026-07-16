# frozen_string_literal: true

module Customers
  class DestroyService < BaseService
    Result = BaseResult[:customer]

    def initialize(customer:)
      @customer = customer

      super
    end

    activity_loggable(
      action: "customer.deleted",
      record: -> { customer }
    )

    def call
      return result.not_found_failure!(resource: "customer") unless customer

      customer.discard!

      Customers::TerminateRelationsJob.perform_later(customer_id: customer.id)

      result.customer = customer
      result
    end

    private

    attr_reader :customer
  end
end
