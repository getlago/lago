# frozen_string_literal: true

module Plans
  class CreateService < BaseService
    Result = BaseResult[:plan]

    def initialize(args, send_webhook: true)
      @args = args
      @send_webhook = send_webhook
      super()
    end

    activity_loggable(
      action: "plan.created",
      record: -> { result.plan }
    )

    def call
      plan = Plan.new(
        organization_id: args[:organization_id],
        name: args[:name],
        invoice_display_name: args[:invoice_display_name],
        code: args[:code],
        description: args[:description],
        interval: args[:interval]&.to_sym,
        pay_in_advance: args[:pay_in_advance],
        amount_cents: args[:amount_cents],
        amount_currency: args[:amount_currency],
        trial_period: args[:trial_period],
        bill_charges_monthly: bill_charges_monthly(args),
        bill_fixed_charges_monthly: bill_fixed_charges_monthly(args)
      )

      chargeables_validation_result = Plans::ChargeablesValidationService.call(
        organization: plan.organization,
        charges: args[:charges],
        fixed_charges: args[:fixed_charges]
      )
      return chargeables_validation_result if chargeables_validation_result.failure?

      ActiveRecord::Base.transaction do
        plan.save!
        create_metadata(plan, args[:metadata]) if !args[:metadata].nil?

        if args[:tax_codes]
          taxes_result = Plans::ApplyTaxesService.call(plan:, tax_codes: args[:tax_codes])
          taxes_result.raise_if_error!
        end

        if args[:usage_thresholds].present? && plan.organization.progressive_billing_enabled?
          UsageThresholds::UpdateService.call!(model: plan, usage_thresholds_params: args[:usage_thresholds], partial: false)
        end

        if args[:charges].present?
          args[:charges].each do |charge_params|
            Charges::CreateService.call!(plan:, params: charge_params_with_code(plan, charge_params))
          end
        end

        if args[:fixed_charges].present?
          args[:fixed_charges].each do |fixed_charge_args|
            FixedCharges::CreateService.call!(plan:, params: fixed_charge_params_with_code(plan, fixed_charge_args))
          end
        end

        if args[:minimum_commitment].present? && License.premium?
          minimum_commitment = args[:minimum_commitment]
          new_commitment = create_commitment(plan, minimum_commitment, :minimum_commitment)
          if minimum_commitment[:tax_codes].present?
            taxes_result = Commitments::ApplyTaxesService.call(
              commitment: new_commitment,
              tax_codes: minimum_commitment[:tax_codes]
            )
            taxes_result.raise_if_error!
          end
        end
      end

      result.plan = plan
      track_plan_created(plan)
      SendWebhookJob.perform_after_commit("plan.created", plan) if send_webhook
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :args, :send_webhook

    def create_commitment(plan, args, commitment_type)
      Commitment.create!(
        organization_id: plan.organization_id,
        plan:,
        commitment_type:,
        invoice_display_name: args[:invoice_display_name],
        amount_cents: args[:amount_cents]
      )
    end

    def create_usage_threshold(plan, args)
      usage_threshold = plan.usage_thresholds.new(
        organization_id: plan.organization_id,
        threshold_display_name: args[:threshold_display_name],
        amount_cents: args[:amount_cents],
        recurring: args[:recurring] || false
      )

      usage_threshold.save!
    end

    def create_metadata(plan, metadata_value)
      plan.create_metadata!(
        organization_id: plan.organization_id,
        value: metadata_value
      )
    end

    def bill_charges_monthly(args)
      return nil unless charges_billable_monthly?(args)

      args[:bill_charges_monthly] || false
    end

    def bill_fixed_charges_monthly(args)
      return nil unless charges_billable_monthly?(args)

      args[:bill_fixed_charges_monthly] || false
    end

    def charges_billable_monthly?(args)
      interval = args[:interval]&.to_sym

      %i[yearly semiannual].include?(interval)
    end

    def charge_params_with_code(plan, charge_params)
      return charge_params if charge_params[:code].present?

      billable_metric = plan.organization.billable_metrics.find_by(id: charge_params[:billable_metric_id])
      return charge_params unless billable_metric

      charge_params.merge(code: Charges::GenerateCodeService.call(plan:, billable_metric:).code)
    end

    def fixed_charge_params_with_code(plan, fixed_charge_params)
      return fixed_charge_params if fixed_charge_params[:code].present?

      add_on = plan.organization.add_ons.find_by(id: fixed_charge_params[:add_on_id])
      return fixed_charge_params unless add_on

      fixed_charge_params.merge(code: FixedCharges::GenerateCodeService.call(plan:, add_on:).code)
    end

    def track_plan_created(plan)
      count_by_charge_model = plan.charges.group(:charge_model).count
      count_by_fixed_charge_model = plan.fixed_charges.group(:charge_model).count

      SegmentTrackJob.perform_later(
        membership_id: CurrentContext.membership,
        event: "plan_created",
        properties: {
          code: plan.code,
          name: plan.name,
          invoice_display_name: plan.invoice_display_name,
          description: plan.description,
          plan_interval: plan.interval,
          plan_amount_cents: plan.amount_cents,
          plan_period: plan.pay_in_advance ? "advance" : "arrears",
          trial: plan.trial_period,
          nb_charges: plan.charges.count,
          nb_standard_charges: count_by_charge_model["standard"] || 0,
          nb_percentage_charges: count_by_charge_model["percentage"] || 0,
          nb_graduated_charges: count_by_charge_model["graduated"] || 0,
          nb_package_charges: count_by_charge_model["package"] || 0,
          nb_fixed_charges: plan.fixed_charges.count,
          nb_standard_fixed_charges: count_by_fixed_charge_model["standard"] || 0,
          nb_graduated_fixed_charges: count_by_fixed_charge_model["graduated"] || 0,
          nb_volume_fixed_charges: count_by_fixed_charge_model["volume"] || 0,
          organization_id: plan.organization_id,
          parent_id: plan.parent_id
        }
      )
    end
  end
end
