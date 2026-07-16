# frozen_string_literal: true

module Subscriptions
  class UpdateOrOverrideChargeService < BaseService
    include Concerns::PlanOverrideConcern
    include Concerns::ChargeOverrideConcern

    Result = BaseResult[:charge]

    def initialize(subscription:, charge:, params:)
      @subscription = subscription
      @charge = charge
      @params = params

      super
    end

    def call
      return result.forbidden_failure! unless License.premium?
      return result.not_found_failure!(resource: "subscription") unless subscription
      return result.not_found_failure!(resource: "charge") unless charge

      ActiveRecord::Base.transaction do
        target_plan = ensure_plan_override
        target_charge = find_or_update_charge_override(target_plan)

        result.charge = target_charge
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :subscription, :charge, :params

    def find_or_update_charge_override(target_plan)
      # NOTE: If the resolved charge already lives on the overridden plan, update it in place.
      return update_charge_override(charge) if charge.plan_id == target_plan.id

      parent_charge = find_parent_charge
      existing_override = target_plan.charges.find_by(parent_id: parent_charge.id)

      if existing_override
        update_charge_override(existing_override)
      else
        create_charge_override(parent_charge, target_plan)
      end
    end

    def create_charge_override(parent_charge, target_plan)
      override_result = Charges::OverrideService.call!(
        charge: parent_charge,
        params: params.merge(plan_id: target_plan.id)
      )
      override_result.charge
    end

    def update_charge_override(existing_charge)
      existing_charge.properties = params[:properties] if params.key?(:properties)
      existing_charge.min_amount_cents = params[:min_amount_cents] if params.key?(:min_amount_cents)
      existing_charge.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
      existing_charge.save!

      if params.key?(:filters)
        filters_result = ::ChargeFilters::CreateOrUpdateBatchService.call(
          charge: existing_charge,
          filters_params: params[:filters]
        )
        filters_result.raise_if_error!
      end

      if params.key?(:applied_pricing_unit) && existing_charge.applied_pricing_unit
        existing_charge.applied_pricing_unit.update!(
          conversion_rate: params[:applied_pricing_unit][:conversion_rate]
        )
      end

      if params.key?(:tax_codes)
        taxes_result = Charges::ApplyTaxesService.call(charge: existing_charge, tax_codes: params[:tax_codes])
        taxes_result.raise_if_error!
      end

      existing_charge.reload
    end
  end
end
