# frozen_string_literal: true

module Charges
  class OverrideService < BaseService
    Result = BaseResult[:charge]

    def initialize(charge:, params:)
      @charge = charge
      @params = params

      super
    end

    def call
      return result unless License.premium?

      ActiveRecord::Base.transaction do
        new_charge = charge.dup.tap do |c|
          c.organization = params[:plan].organization if params[:plan]
          c.plan = params[:plan] if params[:plan]
          c.billable_metric = charge.billable_metric
          c.properties = params[:properties] if params.key?(:properties)
          c.min_amount_cents = params[:min_amount_cents] if params.key?(:min_amount_cents)
          c.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
          c.parent_id = charge.id
          c.filters = charge.filters.map do |filter|
            f = filter.dup
            f.values = filter.values.map(&:dup)
            f
          end
          c.plan_id = params[:plan_id] unless params[:plan]
        end
        new_charge.save!

        if params.key?(:filters)
          filters_result = ChargeFilters::CreateOrUpdateBatchService.call(
            charge: new_charge,
            filters_params: params[:filters]
          )
          filters_result.raise_if_error!
        end

        if charge.applied_pricing_unit
          applied_pricing_unit = charge.applied_pricing_unit
          conversion_rate = params.dig(:applied_pricing_unit, :conversion_rate).presence
          conversion_rate ||= applied_pricing_unit.conversion_rate

          AppliedPricingUnits::CreateService.call!(
            charge: new_charge,
            params: {
              code: applied_pricing_unit.pricing_unit.code,
              conversion_rate:
            }
          )
        end

        if params.key?(:tax_codes)
          taxes_result = Charges::ApplyTaxesService.call(charge: new_charge, tax_codes: params[:tax_codes])
          taxes_result.raise_if_error!
        end

        result.charge = new_charge
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :charge, :params
  end
end
