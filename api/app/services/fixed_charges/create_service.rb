# frozen_string_literal: true

module FixedCharges
  class CreateService < BaseService
    Result = BaseResult[:fixed_charge]

    def initialize(plan:, params:, timestamp: Time.current.to_i, cascade_updates: false)
      @plan = plan
      @params = params
      @timestamp = timestamp.to_i
      @cascade_updates = cascade_updates

      super
    end

    def call
      return result.not_found_failure!(resource: "plan") unless plan

      ActiveRecord::Base.transaction do
        fixed_charge = plan.fixed_charges.new(
          organization_id: plan.organization_id,
          add_on_id: add_on.id,
          code: params[:code],
          invoice_display_name: params[:invoice_display_name],
          charge_model: params[:charge_model],
          parent_id: params[:parent_id],
          pay_in_advance: params[:pay_in_advance] || false,
          prorated: params[:prorated] || false,
          units: params[:units] || 0
        )

        properties = params[:properties].presence || ChargeModels::BuildDefaultPropertiesService.call(fixed_charge.charge_model)
        fixed_charge.properties = ChargeModels::FilterPropertiesService.call(
          chargeable: fixed_charge,
          properties:
        ).properties

        fixed_charge.save!

        if params[:tax_codes]
          taxes_result = FixedCharges::ApplyTaxesService.call(fixed_charge:, tax_codes: params[:tax_codes])
          taxes_result.raise_if_error!
        end

        FixedCharges::EmitEventsService.call!(
          fixed_charge:,
          apply_units_immediately: !!params[:apply_units_immediately],
          timestamp:
        )

        result.fixed_charge = fixed_charge
      end

      if cascade_updates && result.success? && plan.children.exists?
        FixedCharges::CreateChildrenJob.perform_later(fixed_charge: result.fixed_charge, payload: params)
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :code, error_code: "value_already_exist")
    rescue ActiveRecord::RecordNotFound => e
      result.not_found_failure!(resource: e.model.underscore)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :plan, :params, :timestamp, :cascade_updates

    delegate :organization, to: :plan

    def add_on
      @add_on ||= if params[:add_on_id].present?
        organization.add_ons.find(params[:add_on_id])
      elsif params[:add_on_code].present?
        organization.add_ons.find_by!(code: params[:add_on_code])
      else
        raise ArgumentError, "Either add_on_id or add_on_code must be provided"
      end
    end
  end
end
