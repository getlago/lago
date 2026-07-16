# frozen_string_literal: true

module Plans
  class UpdateService < BaseService
    Result = BaseResult[:plan]

    def initialize(plan:, params:, partial_metadata: false, send_webhook: true)
      @plan = plan
      @params = params
      @timestamp = Time.current.to_i
      @partial_metadata = partial_metadata
      @send_webhook = send_webhook
      super
    end

    activity_loggable(
      action: "plan.updated",
      record: -> { plan },
      condition: -> { plan&.parent_id.nil? }
    )

    def call
      return result.not_found_failure!(resource: "plan") unless plan

      old_amount_cents = plan.amount_cents

      plan.name = params[:name] if params.key?(:name)
      plan.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
      plan.description = params[:description] if params.key?(:description)
      plan.amount_cents = params[:amount_cents] if params.key?(:amount_cents)

      # NOTE: If plan is attached to subscriptions the editable attributes are:
      #       name, invoice_display_name, description, amount_cents
      unless plan.attached_to_subscriptions?
        plan.code = params[:code] if params.key?(:code)
        plan.interval = params[:interval].to_sym if params.key?(:interval)
        plan.pay_in_advance = params[:pay_in_advance] if params.key?(:pay_in_advance)
        plan.amount_currency = params[:amount_currency] if params.key?(:amount_currency)
        plan.trial_period = params[:trial_period] if params.key?(:trial_period)
        plan.bill_charges_monthly = bill_charges_monthly?
        plan.bill_fixed_charges_monthly = bill_fixed_charges_monthly?
      end

      chargeables_validation_result = Plans::ChargeablesValidationService.call(
        organization: plan.organization,
        charges: params[:charges],
        fixed_charges: params[:fixed_charges]
      )
      return chargeables_validation_result if chargeables_validation_result.failure?

      ActiveRecord::Base.transaction do
        plan.save!
        update_metadata!

        if params[:tax_codes]
          taxes_result = Plans::ApplyTaxesService.call(plan:, tax_codes: params[:tax_codes])
          taxes_result.raise_if_error!
        end

        process_charges(plan, params[:charges]) if params[:charges]
        process_fixed_charges if params[:fixed_charges]

        if params.key?(:usage_thresholds) && License.premium?
          Plans::UpdateUsageThresholdsService.call(plan:, usage_thresholds_params: params[:usage_thresholds])
        end

        process_minimum_commitment(plan, params[:minimum_commitment]) if params[:minimum_commitment] && License.premium?

        if old_amount_cents != plan.amount_cents
          process_downgraded_subscriptions
          process_pending_subscriptions
        end
      end

      cascade_subscription_fee_update(old_amount_cents)

      plan.invoices.draft.update_all(ready_to_be_refreshed: true) # rubocop:disable Rails/SkipsModelValidations

      SendWebhookJob.perform_after_commit("plan.updated", plan) if send_webhook
      result.plan = plan.reload
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :plan, :params, :timestamp, :partial_metadata, :send_webhook

    delegate :organization, to: :plan

    def update_metadata!
      return unless params.key?(:metadata)

      value = params[:metadata]&.then { |m| m.respond_to?(:to_unsafe_h) ? m.to_unsafe_h : m.to_h }
      result = Metadata::UpdateItemService.call!(owner: plan, value:, partial: partial_metadata.present?)
      @metadata_changed = result.metadata_changed
    end

    def bill_charges_monthly?
      return unless billable_monthly?

      params[:bill_charges_monthly] || false
    end

    def bill_fixed_charges_monthly?
      return unless billable_monthly?

      params[:bill_fixed_charges_monthly] || false
    end

    def billable_monthly?
      @billable_monthly ||= params[:interval]&.to_sym == :yearly || params[:interval]&.to_sym == :semiannual
    end

    def cascade_needed?
      cascade? && plan.children.present?
    end

    def cascade_subscription_fee_update(old_amount_cents)
      return unless cascade_needed?
      return if old_amount_cents == plan.amount_cents

      plan.children.where(amount_cents: old_amount_cents).find_each do |p|
        Plans::UpdateAmountJob.perform_later(plan: p, amount_cents: plan.amount_cents, expected_amount_cents: old_amount_cents)
      end
    end

    def cascade_charge_creation(charge, payload_charge)
      return unless cascade_needed?

      Charges::CreateChildrenJob.perform_later(charge:, payload: payload_charge)
    end

    def cascade_charge_removal(charge)
      return unless cascade_needed?

      Charges::DestroyChildrenJob.perform_later(charge.id)
    end

    def cascade_charge_update(charge, payload_charge)
      return unless cascade_needed?

      old_parent_attrs = charge.attributes
      old_parent_applied_pricing_unit_attrs = charge.applied_pricing_unit&.attributes
      before_filters = capture_filters(charge) if payload_charge.key?(:filters)

      after_commit do
        Charges::UpdateChildrenJob.perform_later(
          params: payload_charge.except(:filters).deep_stringify_keys,
          old_parent_attrs:,
          old_parent_applied_pricing_unit_attrs:
        )

        cascade_filter_changes(charge, before_filters, payload_charge[:filters]) if before_filters
      end
    end

    def capture_filters(charge)
      charge.filters.includes(values: :billable_metric_filter).map do |f|
        {
          values: f.to_h.deep_stringify_keys,
          properties: f.properties,
          invoice_display_name: f.invoice_display_name
        }
      end
    end

    def cascade_filter_changes(charge, before, payload_filters)
      after = (payload_filters || []).map do |fp|
        {
          values: (fp[:values] || {}).deep_stringify_keys,
          properties: fp[:properties]&.deep_stringify_keys,
          invoice_display_name: fp[:invoice_display_name]
        }
      end

      ChargeFilters::CascadeDispatcher.call(charge:, before:, after:)
    end

    def cascade_fixed_charge_removal(fixed_charge)
      return unless cascade_needed?

      FixedCharges::DestroyChildrenJob.perform_later(fixed_charge.id)
    end

    def cascade?
      ActiveModel::Type::Boolean.new.cast(params[:cascade_updates])
    end

    def process_minimum_commitment(plan, params)
      if params.present?
        minimum_commitment = plan.minimum_commitment ||
          Commitment.new(organization_id: plan.organization_id, plan:, commitment_type: "minimum_commitment")

        minimum_commitment.amount_cents = params[:amount_cents] if params.key?(:amount_cents)
        minimum_commitment.invoice_display_name = params[:invoice_display_name] if params.key?(:invoice_display_name)
        minimum_commitment.save!
      end
      plan.minimum_commitment.destroy! if params.blank? && plan.minimum_commitment

      if params[:tax_codes]
        taxes_result = Commitments::ApplyTaxesService.call(
          commitment: minimum_commitment,
          tax_codes: params[:tax_codes]
        )
        taxes_result.raise_if_error!
      end

      minimum_commitment
    end

    def process_charges(plan, params_charges)
      created_charges_ids = []

      hash_charges = params_charges.map { |c| c.to_h.deep_symbolize_keys }
      hash_charges.each do |payload_charge|
        charge = plan.charges.find_by(id: payload_charge[:id])

        if charge
          cascade_charge_update(charge, payload_charge)
          Charges::UpdateService.call!(charge:, params: payload_charge)

          next
        end

        create_charge_result = Charges::CreateService.call!(plan:, params: charge_params_with_code(payload_charge))

        after_commit { cascade_charge_creation(create_charge_result.charge, payload_charge) }
        created_charges_ids.push(create_charge_result.charge.id)
      end

      # NOTE: Delete charges that are no more linked to the plan
      sanitize_charges(plan, hash_charges, created_charges_ids)
    end

    def sanitize_charges(plan, args_charges, created_charges_ids)
      args_charges_ids = args_charges.map { |c| c[:id] }.compact
      charges_ids = plan.charges.pluck(:id) - args_charges_ids - created_charges_ids
      plan.charges.where(id: charges_ids).find_each do |charge|
        after_commit { cascade_charge_removal(charge) }
        Charges::DestroyService.call(charge:)
      end
    end

    def process_fixed_charges
      cascade_fixed_charges_payload = []
      created_fixed_charges_ids = []

      hash_fixed_charges = params[:fixed_charges].map { |c| c.to_h.deep_symbolize_keys }
      hash_fixed_charges.each do |payload_fixed_charge|
        fixed_charge = plan.fixed_charges.find_by(id: payload_fixed_charge[:id])

        if fixed_charge
          cascade_fixed_charges_payload << payload_fixed_charge.merge(
            old_parent_attrs: fixed_charge.attributes,
            action: :update
          )
          FixedCharges::UpdateService.call!(fixed_charge:, params: payload_fixed_charge, timestamp:, trigger_billing: false)

          next
        end

        create_fixed_charge_result = FixedCharges::CreateService.call!(plan:, params: fixed_charge_params_with_code(payload_fixed_charge), timestamp:)

        cascade_fixed_charges_payload << payload_fixed_charge.merge(
          parent_id: create_fixed_charge_result.fixed_charge.id,
          code: create_fixed_charge_result.fixed_charge.code,
          action: :create
        )

        created_fixed_charges_ids.push(create_fixed_charge_result.fixed_charge.id)
      end

      # NOTE: Delete fixed_charges that are no more linked to the plan
      sanitize_fixed_charges(plan, hash_fixed_charges, created_fixed_charges_ids)

      trigger_pay_in_advance_billing if plan.fixed_charges.pay_in_advance.exists?

      cascade_fixed_charges(cascade_fixed_charges_payload)
    end

    def cascade_fixed_charges(cascade_fixed_charges_payload)
      return unless cascade_needed?
      return unless plan.children.exists?

      FixedCharges::CascadePlanUpdateJob.perform_later(
        plan: plan,
        cascade_fixed_charges_payload:,
        timestamp:
      )
    end

    def trigger_pay_in_advance_billing
      Invoices::CreateAllPayInAdvanceFixedChargesJob.perform_after_commit(plan, timestamp)
    end

    def sanitize_fixed_charges(plan, args_fixed_charges, created_fixed_charges_ids)
      args_fixed_charges_ids = args_fixed_charges.map { |c| c[:id] }.compact
      fixed_charges_ids = plan.fixed_charges.pluck(:id) - args_fixed_charges_ids - created_fixed_charges_ids
      plan.fixed_charges.where(id: fixed_charges_ids).find_each do |fixed_charge|
        after_commit { cascade_fixed_charge_removal(fixed_charge) }
        FixedCharges::DestroyService.call(fixed_charge:)
      end
    end

    def charge_params_with_code(charge_params)
      return charge_params if charge_params[:code].present?

      billable_metric = organization.billable_metrics.find_by(id: charge_params[:billable_metric_id])
      return charge_params unless billable_metric

      charge_params.merge(code: Charges::GenerateCodeService.call(plan:, billable_metric:).code)
    end

    def fixed_charge_params_with_code(fixed_charge_params)
      return fixed_charge_params if fixed_charge_params[:code].present?

      add_on = organization.add_ons.find_by(id: fixed_charge_params[:add_on_id])
      return fixed_charge_params unless add_on

      fixed_charge_params.merge(code: FixedCharges::GenerateCodeService.call(plan:, add_on:).code)
    end

    # NOTE: We should remove pending subscriptions
    #       if plan has been downgraded but amount cents became less than downgraded value. This pending subscription
    #       is not relevant in this case and downgrade should be ignored
    def process_downgraded_subscriptions
      return unless plan.subscriptions.active.exists?

      Subscription.where(previous_subscription: plan.subscriptions.active, status: :pending).find_each do |sub|
        sub.mark_as_canceled! if plan.amount_cents < sub.plan.amount_cents
      end
    end

    # NOTE: If new plan yearly amount is higher than its value before the update
    #       and there are pending subscriptions for the plan,
    #       this is a plan upgrade, old subscription must be terminated and billed
    #       new subscription with updated plan must be activated inmediately.
    def process_pending_subscriptions
      Subscription.where(plan:, status: :pending).find_each do |subscription|
        next unless subscription.previous_subscription

        if plan.yearly_amount_cents >= subscription.previous_subscription.plan.yearly_amount_cents
          upgrade_params = {name: subscription.name}

          if subscription.activation_rules.any?
            upgrade_params[:activation_rules] = subscription.activation_rules.map do |rule|
              {type: rule.type, timeout_hours: rule.timeout_hours}
            end
          end

          Subscriptions::PlanUpgradeService.call(
            current_subscription: subscription.previous_subscription,
            plan: plan,
            params: upgrade_params
          ).raise_if_error!
        end
      end
    end
  end
end
