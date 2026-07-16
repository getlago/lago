# frozen_string_literal: true

module FixedCharges
  class OverrideService < BaseService
    Result = BaseResult[:fixed_charge]

    def initialize(fixed_charge:, params:, subscription: nil)
      @fixed_charge = fixed_charge
      @params = params
      @subscription = subscription

      super
    end

    def call
      return result unless License.premium?
      return result.forbidden_failure!(code: "cannot_override_charge_model") if params[:charge_model] && fixed_charge.charge_model != params[:charge_model]

      ActiveRecord::Base.transaction do
        new_fixed_charge = fixed_charge.dup.tap do |c|
          if params.key?(:properties)
            properties = params[:properties].presence
            c.properties = ChargeModels::FilterPropertiesService.call(
              chargeable: fixed_charge,
              properties:
            ).properties
          end
          c.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
          c.units = params[:units] if params.key?(:units)
          c.parent_id = fixed_charge.id
          c.plan_id = params[:plan_id]
        end
        new_fixed_charge.save!

        FixedCharges::EmitEventsService.call!(
          fixed_charge: new_fixed_charge,
          subscription:,
          apply_units_immediately: !!params[:apply_units_immediately]
        )

        if params.key?(:tax_codes)
          taxes_result = FixedCharges::ApplyTaxesService.call(fixed_charge: new_fixed_charge, tax_codes: params[:tax_codes])
          taxes_result.raise_if_error!
        end

        result.fixed_charge = new_fixed_charge
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :fixed_charge, :params, :subscription
  end
end
