# frozen_string_literal: true

module Subscriptions
  class UpdateOrOverrideFixedChargeService < BaseService
    include Concerns::PlanOverrideConcern
    include Concerns::FixedChargeUnitsOverrideDetectionConcern
    include Concerns::FixedChargeUnitsOverridePromotionConcern

    Result = BaseResult[:fixed_charge]

    def initialize(subscription:, fixed_charge:, params:)
      @subscription = subscription
      @fixed_charge = fixed_charge
      @params = params
      @subscription_plan_parent_present = subscription&.plan&.parent_id.present?

      super
    end

    def call
      return result.forbidden_failure! unless License.premium?
      return result.not_found_failure!(resource: "subscription") unless subscription
      return result.not_found_failure!(resource: "fixed_charge") unless fixed_charge

      ActiveRecord::Base.transaction do
        result.fixed_charge = units_only_change? ? override_units_only : override_via_plan
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :subscription, :fixed_charge, :params, :subscription_plan_parent_present

    def units_only_change?
      return false if subscription_plan_parent_present

      units_only_fixed_charge_params?(params)
    end

    def override_units_only
      parent_fixed_charge = fixed_charge.parent_or_self

      Subscriptions::FixedChargeUnitsOverrides::WriteService.call!(
        subscription:,
        fixed_charge: parent_fixed_charge,
        units: params[:units],
        apply_units_immediately: params[:apply_units_immediately]
      )

      parent_fixed_charge
    end

    def override_via_plan
      parent_fixed_charge = fixed_charge.parent_or_self
      target_plan = ensure_plan_override(params: promoted_plan_override_params(parent_fixed_charge))
      target_fixed_charge = find_or_create_fixed_charge_override(parent_fixed_charge, target_plan)

      publish_invoice_pay_in_advance_job(target_fixed_charge)

      target_fixed_charge
    end

    def plan_override_params(parent_fixed_charge)
      return {} if subscription_plan_parent_present

      {fixed_charges: [params.merge(id: parent_fixed_charge.id)]}
    end

    # Seed the override plan with the customer's existing units override rows so
    # they survive the clone, while the user's current change wins for the
    # fixed_charge being edited. The seeded units are applied during clone
    # creation; find_or_create_fixed_charge_override reloads (no second event).
    def promoted_plan_override_params(parent_fixed_charge)
      base_entries = plan_override_params(parent_fixed_charge)[:fixed_charges] || []
      promoted_fixed_charges = promote_units_overrides_to_fixed_charges_params(base_entries)
      promoted_fixed_charges.any? ? {fixed_charges: promoted_fixed_charges} : {}
    end

    def find_or_create_fixed_charge_override(parent_fixed_charge, target_plan)
      existing_override = target_plan.fixed_charges.find_by(parent_id: parent_fixed_charge.id)

      unless subscription_plan_parent_present
        if existing_override
          return existing_override.reload
        end

        return create_fixed_charge_override(parent_fixed_charge, target_plan)
      end

      if existing_override
        update_fixed_charge_override(existing_override)
      else
        create_fixed_charge_override(parent_fixed_charge, target_plan)
      end
    end

    def create_fixed_charge_override(parent_fixed_charge, target_plan)
      override_result = FixedCharges::OverrideService.call!(
        fixed_charge: parent_fixed_charge,
        params: params.merge(plan_id: target_plan.id),
        subscription:
      )
      override_result.fixed_charge
    end

    def update_fixed_charge_override(existing_fixed_charge)
      if params.key?(:properties)
        existing_fixed_charge.properties = ChargeModels::FilterPropertiesService.call(
          chargeable: existing_fixed_charge,
          properties: params[:properties].presence
        ).properties
      end
      existing_fixed_charge.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
      existing_fixed_charge.units = params[:units] if params.key?(:units)
      existing_fixed_charge.save!

      FixedCharges::EmitEventsService.call!(
        fixed_charge: existing_fixed_charge,
        subscription:,
        apply_units_immediately: !!params[:apply_units_immediately]
      )

      if params.key?(:tax_codes)
        taxes_result = FixedCharges::ApplyTaxesService.call(fixed_charge: existing_fixed_charge, tax_codes: params[:tax_codes])
        taxes_result.raise_if_error!
      end

      existing_fixed_charge.reload
    end

    def publish_invoice_pay_in_advance_job(target_fixed_charge)
      return if subscription.payment_gated?
      return unless params.key?(:units)
      return unless params[:apply_units_immediately]
      return unless target_fixed_charge.pay_in_advance?

      Invoices::CreatePayInAdvanceFixedChargesJob.perform_after_commit(subscription, Time.current.to_i)
    end
  end
end
