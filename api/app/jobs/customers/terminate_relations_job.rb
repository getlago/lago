# frozen_string_literal: true

module Customers
  class TerminateRelationsJob < ApplicationJob
    def perform(customer_id:)
      customer = Customer.with_discarded.find_by(id: customer_id)

      result = Customers::TerminateRelationsService.call(customer:)
      result.raise_if_error!
    end
  end
end
