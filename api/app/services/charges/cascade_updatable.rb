# frozen_string_literal: true

module Charges
  module CascadeUpdatable
    extend ActiveSupport::Concern

    private

    def trigger_cascade(old_filters_attrs, old_parent_attrs: nil, old_applied_pricing_unit_attrs: nil)
      return unless cascade_updates
      return unless charge.children.exists?

      Charges::UpdateChildrenJob.perform_later(
        params: build_cascade_params.deep_stringify_keys,
        old_parent_attrs: old_parent_attrs || charge.attributes,
        old_parent_applied_pricing_unit_attrs: old_applied_pricing_unit_attrs || charge.applied_pricing_unit&.attributes
      )

      cascade_filter_changes(old_filters_attrs)
    end

    def cascade_filter_changes(old_filters_attrs)
      before = old_filters_attrs.map do |f|
        {
          values: f[:values].deep_stringify_keys,
          properties: f[:properties]&.deep_stringify_keys,
          invoice_display_name: f[:invoice_display_name]
        }
      end

      charge.filters.reset
      after = charge.filters.includes(values: :billable_metric_filter).unscope(:order).find_each.map do |filter|
        {
          values: filter.to_h.deep_stringify_keys,
          properties: filter.properties.deep_stringify_keys,
          invoice_display_name: filter.invoice_display_name
        }
      end

      ChargeFilters::CascadeDispatcher.call(charge:, before:, after:)
    end

    def build_cascade_params
      {
        code: charge.code,
        charge_model: charge.charge_model,
        properties: charge.properties
      }
    end

    def capture_old_filters_attrs
      charge.filters.includes(values: :billable_metric_filter).map do |f|
        {id: f.id, properties: f.properties, invoice_display_name: f.invoice_display_name, values: f.to_h}
      end
    end

    def capture_old_applied_pricing_unit_attrs
      charge.applied_pricing_unit&.attributes
    end
  end
end
