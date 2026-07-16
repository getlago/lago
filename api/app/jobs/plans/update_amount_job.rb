# frozen_string_literal: true

module Plans
  class UpdateAmountJob < ApplicationJob
    queue_as "default"

    def perform(plan:, amount_cents:, expected_amount_cents:)
      Plans::UpdateAmountService.call(plan:, amount_cents:, expected_amount_cents:).raise_if_error!
    end
  end
end
