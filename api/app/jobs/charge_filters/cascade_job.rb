# frozen_string_literal: true

module ChargeFilters
  class CascadeJob < ApplicationJob
    queue_as :default

    def perform(charge_id, action, filter_values, old_properties, new_properties, invoice_display_name)
      charge = Charge.find_by(id: charge_id)
      return unless charge

      ChargeFilters::CascadeService.call!(
        charge:,
        action:,
        filter_values:,
        old_properties:,
        new_properties:,
        invoice_display_name:
      )
    end
  end
end
