# frozen_string_literal: true

module Charges
  class CreateService < BaseService
    Result = BaseResult[:charge]

    def initialize(plan:, params:, cascade_updates: false)
      @plan = plan
      @params = params
      @cascade_updates = cascade_updates

      super
    end

    def call
      return result.not_found_failure!(resource: "plan") unless plan
      return result.not_found_failure!(resource: "billable_metric") unless billable_metric

      ActiveRecord::Base.transaction do
        charge = plan.charges.new(
          organization_id: plan.organization_id,
          billable_metric_id: params[:billable_metric_id],
          code: params[:code],
          invoice_display_name: params[:invoice_display_name],
          amount_currency: params[:amount_currency],
          charge_model: params[:charge_model],
          parent_id: params[:parent_id],
          pay_in_advance: params[:pay_in_advance] || false,
          prorated: params[:prorated] || false
        )

        properties = params[:properties].presence || ChargeModels::BuildDefaultPropertiesService.call(charge.charge_model)
        charge.properties = ChargeModels::FilterPropertiesService.call(
          chargeable: charge,
          properties:
        ).properties

        if params[:filters].present?
          charge.save!
          ChargeFilters::CreateOrUpdateBatchService.call(
            charge:,
            filters_params: params[:filters].map(&:with_indifferent_access)
          ).raise_if_error!
        end

        if License.premium?
          charge.invoiceable = params[:invoiceable] unless params[:invoiceable].nil?
          charge.regroup_paid_fees = params[:regroup_paid_fees] if params.key?(:regroup_paid_fees)
          charge.min_amount_cents = params[:min_amount_cents] || 0

          if plan.organization.events_targeting_wallets_enabled?
            charge.accepts_target_wallet = params[:accepts_target_wallet] || false
          end
        end

        charge.save!

        AppliedPricingUnits::CreateService.call!(charge:, params: params[:applied_pricing_unit])

        if params[:tax_codes]
          taxes_result = Charges::ApplyTaxesService.call(charge:, tax_codes: params[:tax_codes])
          taxes_result.raise_if_error!
        end

        result.charge = charge
      end

      if cascade_updates && result.success? && result.charge.plan.children.exists?
        Charges::CreateChildrenJob.perform_later(charge: result.charge, payload: params)
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :code, error_code: "value_already_exist")
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :plan, :params, :cascade_updates

    def billable_metric
      @billable_metric ||= plan.organization.billable_metrics.find_by(id: params[:billable_metric_id])
    end
  end
end
