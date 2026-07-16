# frozen_string_literal: true

module ChargeFilters
  module CascadeDispatcher
    module_function

    # Diffs `before` against `after` and enqueues one ChargeFilters::CascadeJob
    # per change. `before` and `after` are arrays of:
    #   { values: {"key" => [...]}, properties: {...} | nil, invoice_display_name: "..." }
    # `values` and `properties` must be string-keyed.
    def call(charge:, before:, after:)
      before_by_values = before.index_by { |f| f[:values] }

      after.each do |new_filter|
        existing = before_by_values.delete(new_filter[:values])

        next if existing &&
          existing[:properties] == new_filter[:properties] &&
          existing[:invoice_display_name] == new_filter[:invoice_display_name]

        ChargeFilters::CascadeJob.perform_later(
          charge.id,
          existing ? "update" : "create",
          new_filter[:values],
          existing&.dig(:properties),
          new_filter[:properties],
          new_filter[:invoice_display_name]
        )
      end

      before_by_values.each_value do |old|
        ChargeFilters::CascadeJob.perform_later(
          charge.id,
          "destroy",
          old[:values],
          old[:properties],
          nil,
          old[:invoice_display_name]
        )
      end
    end
  end
end
