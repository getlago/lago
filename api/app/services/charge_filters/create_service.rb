# frozen_string_literal: true

module ChargeFilters
  class CreateService < BaseService
    include ChargeFilters::FilterCascadable

    Result = BaseResult[:charge_filter]

    def initialize(charge:, params:, cascade_updates: false)
      @charge = charge
      @params = params
      @cascade_updates = cascade_updates

      super
    end

    def call
      return result.not_found_failure!(resource: "charge") unless charge
      return result.single_validation_failure!(field: :values, error_code: "value_is_mandatory") if params[:values].blank?

      ActiveRecord::Base.transaction do
        charge_filter = charge.filters.create!(
          organization_id: charge.organization_id,
          invoice_display_name: params[:invoice_display_name],
          properties: filtered_properties
        )

        create_filter_values(charge_filter)

        result.charge_filter = charge_filter
      end

      trigger_filter_cascade(
        action: "create",
        filter_values: result.charge_filter.to_h,
        new_properties: result.charge_filter.properties,
        invoice_display_name: result.charge_filter.invoice_display_name
      )

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :charge, :params, :cascade_updates

    def filtered_properties
      ChargeModels::FilterPropertiesService.call(
        chargeable: charge,
        properties: params[:properties]&.deep_symbolize_keys&.except(:presentation_group_keys)
      ).properties
    end

    def create_filter_values(charge_filter)
      params[:values].each do |key, values|
        billable_metric_filter = charge.billable_metric.filters.find_by(key:)

        filter_value = charge_filter.values.new(
          billable_metric_filter_id: billable_metric_filter&.id,
          organization_id: charge.organization_id
        )
        filter_value.values = values
        filter_value.save!
      end
    end
  end
end
