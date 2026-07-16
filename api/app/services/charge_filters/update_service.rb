# frozen_string_literal: true

module ChargeFilters
  class UpdateService < BaseService
    include ChargeFilters::FilterCascadable

    Result = BaseResult[:charge_filter]

    def initialize(charge_filter:, params:, cascade_updates: false)
      @charge_filter = charge_filter
      @params = params
      @cascade_updates = cascade_updates

      super
    end

    def call
      return result.not_found_failure!(resource: "charge_filter") unless charge_filter

      old_properties = charge_filter.properties.deep_dup

      ActiveRecord::Base.transaction do
        charge_filter.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
        charge_filter.properties = filtered_properties if params.key?(:properties)
        charge_filter.save!

        result.charge_filter = charge_filter
      end

      trigger_filter_cascade(
        action: "update",
        filter_values: charge_filter.to_h,
        old_properties:,
        new_properties: charge_filter.properties,
        invoice_display_name: charge_filter.invoice_display_name
      )

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :charge_filter, :params, :cascade_updates

    delegate :charge, to: :charge_filter

    def filtered_properties
      ChargeModels::FilterPropertiesService.call(
        chargeable: charge,
        properties: params[:properties]&.deep_symbolize_keys&.except(:presentation_group_keys)
      ).properties
    end
  end
end
