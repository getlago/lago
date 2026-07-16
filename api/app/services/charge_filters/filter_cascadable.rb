# frozen_string_literal: true

module ChargeFilters
  module FilterCascadable
    extend ActiveSupport::Concern

    private

    def trigger_filter_cascade(action:, filter_values:, old_properties: nil, new_properties: nil, invoice_display_name: nil)
      return unless cascade_updates
      return unless charge.children.exists?

      ChargeFilters::CascadeJob.perform_later(
        charge.id,
        action,
        filter_values.deep_stringify_keys,
        old_properties&.deep_stringify_keys,
        new_properties&.deep_stringify_keys,
        invoice_display_name
      )
    end
  end
end
