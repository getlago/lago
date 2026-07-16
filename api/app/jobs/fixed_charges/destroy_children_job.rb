# frozen_string_literal: true

module FixedCharges
  class DestroyChildrenJob < ApplicationJob
    queue_as :default

    def perform(fixed_charge_id)
      fixed_charge = FixedCharge.with_discarded.find_by(id: fixed_charge_id)
      FixedCharges::DestroyChildrenService.call!(fixed_charge)
    end
  end
end
