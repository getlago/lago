# frozen_string_literal: true

module Subscriptions
  class UpdateService < BaseService
    include Subscriptions::Concerns::BillingEntityResolutionConcern
    include Subscriptions::Concerns::FixedChargeUnitsOverrideDetectionConcern
    include Subscriptions::Concerns::FixedChargeUnitsOverridePromotionConcern

    Result = BaseResult[:subscription, :payment_method]

    def initialize(subscription:, params:)
      @subscription = subscription
      @params = params
      super
    end

    activity_loggable(
      action: "subscription.updated",
      record: -> { subscription },
      condition: -> { !subscription&.starting_in_the_future? },
      after_commit: true
    )

    def call
      return result.not_found_failure!(resource: "subscription") unless subscription
      return result.not_allowed_failure!(code: "subscription_incomplete") if subscription.incomplete?

      unless valid?(
        customer: subscription.customer,
        plan: subscription.plan,
        subscription_at: params.key?(:subscription_at) ? params[:subscription_at] : subscription.subscription_at,
        ending_at: params[:ending_at],
        on_termination_credit_note: params[:on_termination_credit_note],
        on_termination_invoice: params[:on_termination_invoice],
        payment_method: params[:payment_method],
        activation_rules: params[:activation_rules],
        subscription_type: "update",
        subscription:
      )
        return result
      end

      # TODO: Remove check we stop supporting `plan_overrides.usage_thresholds`
      if params[:usage_thresholds].present? && params.dig(:plan_overrides, :usage_thresholds).present?
        return result.validation_failure!(errors: {
          "plan_overrides.usage_thresholds": ["incompatible_params"],
          usage_thresholds: ["incompatible_params"]
        })
      end

      return result.forbidden_failure! if !License.premium? && params.key?(:plan_overrides)

      ActiveRecord::Base.transaction do
        subscription.name = params[:name] if params.key?(:name)
        subscription.ending_at = params[:ending_at] if params.key?(:ending_at)
        subscription.progressive_billing_disabled = params[:progressive_billing_disabled] if params.key?(:progressive_billing_disabled)
        subscription.consolidate_invoice = params[:consolidate_invoice] if params.key?(:consolidate_invoice)

        if pay_in_advance? && params.key?(:on_termination_credit_note)
          subscription.on_termination_credit_note = params[:on_termination_credit_note]
        end

        if params.key?(:on_termination_invoice)
          subscription.on_termination_invoice = params[:on_termination_invoice]
        end

        if params.key?(:payment_method)
          subscription.payment_method_type = params[:payment_method][:payment_method_type] if params[:payment_method].key?(:payment_method_type)
          subscription.payment_method_id = params[:payment_method][:payment_method_id] if params[:payment_method].key?(:payment_method_id)
        end

        if subscription.organization.feature_flag_enabled?(:multi_entity_billing) &&
            (params.key?(:billing_entity_id) || params.key?(:billing_entity_code))
          new_billing_entity = resolve_billing_entity(organization: subscription.organization, params:)
          subscription.billing_entity = new_billing_entity
        end

        if units_only_plan_overrides_change?
          apply_units_only_plan_overrides
        elsif params.key?(:plan_overrides)
          subscription.plan = handle_plan_override.plan
        end

        if params.key?(:usage_thresholds)
          UpdateUsageThresholdsService.call!(subscription:, usage_thresholds_params: params[:usage_thresholds], partial: false)
        end

        if params.key?(:activation_rules) && !subscription_at_changing_to_past?
          Subscriptions::ActivationRules::ApplyService.call!(
            subscription:,
            activation_rules: params[:activation_rules]
          )
        end

        if subscription.starting_in_the_future? && params.key?(:subscription_at)
          subscription.subscription_at = params[:subscription_at]

          process_subscription_at_change(subscription)
        else
          subscription.save!

          if subscription.active? && subscription.fixed_charges.pay_in_advance.any? && subscription.plan_id_previously_changed?
            Invoices::CreatePayInAdvanceFixedChargesJob.perform_after_commit(subscription, Time.current.to_i)
          end

          SendWebhookJob.perform_after_commit("subscription.updated", subscription)

          if subscription.should_sync_hubspot_subscription?
            Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob.perform_after_commit(subscription:)
          end
        end

        InvoiceCustomSections::AttachToResourceService.call(resource: subscription, params:)
      end

      result.subscription = subscription
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :subscription, :params

    def pay_in_advance?
      subscription.plan.pay_in_advance?
    end

    def subscription_at_changing_to_past?
      return false unless subscription.starting_in_the_future?
      return false unless params.key?(:subscription_at)

      DateTime.parse(params[:subscription_at]).to_date < Date.current
    end

    def process_subscription_at_change(subscription)
      if subscription.subscription_at.future? || (subscription.subscription_at.today? && subscription.activation_rules.any?)
        subscription.pending!
        return
      end

      if subscription.activation_rules.any?
        Subscriptions::ActivationRules::ApplyService.call!(
          subscription:,
          activation_rules: []
        )
      end

      subscription.mark_as_active!(subscription.subscription_at)

      EmitFixedChargeEventsService.call!(
        subscriptions: [subscription],
        timestamp: subscription.started_at + 1.second
      )

      if subscription.subscription_at.today?
        if subscription.plan.pay_in_advance?
          BillSubscriptionJob.perform_after_commit([subscription], Time.current.to_i, invoicing_reason: :subscription_starting)
        elsif subscription.fixed_charges.pay_in_advance.any?
          Invoices::CreatePayInAdvanceFixedChargesJob.perform_after_commit(subscription, subscription.started_at + 1.second)
        end
      end
    end

    def handle_plan_override
      current_plan = subscription.plan

      if current_plan.parent_id
        Plans::UpdateService.call!(
          plan: current_plan,
          params: plan_update_params_with_full_fixed_charges(current_plan)
        )
      else
        Plans::OverrideService.call!(
          plan: current_plan,
          params: plan_override_params_with_promoted_units,
          subscription:
        )
      end
    end

    def plan_override_params_with_promoted_units
      override_params = params[:plan_overrides].to_h.with_indifferent_access
      override_params[:fixed_charges] = promote_units_overrides_to_fixed_charges_params(
        override_params[:fixed_charges] || []
      )
      override_params
    end

    def units_only_plan_overrides_change?
      return @units_only_plan_overrides_change if defined?(@units_only_plan_overrides_change)

      @units_only_plan_overrides_change = !subscription.plan.parent_id &&
        params.key?(:plan_overrides) &&
        units_only_fixed_charges_plan_overrides?(params[:plan_overrides])
    end

    def apply_units_only_plan_overrides
      timestamp = Time.current.to_i

      params[:plan_overrides][:fixed_charges].each do |entry|
        entry = entry.to_h.symbolize_keys
        fixed_charge = subscription.plan.fixed_charges.find_by(id: entry[:id])
        result.not_found_failure!(resource: "fixed_charge").raise_if_error! unless fixed_charge

        Subscriptions::FixedChargeUnitsOverrides::WriteService.call!(
          subscription:,
          fixed_charge:,
          units: entry[:units],
          apply_units_immediately: !!entry[:apply_units_immediately],
          timestamp:
        )
      end
    end

    def plan_update_params_with_full_fixed_charges(plan)
      payload = params[:plan_overrides].to_h.with_indifferent_access
      return payload unless payload.key?(:fixed_charges)

      fixed_charges_by_id = plan.fixed_charges.index_by(&:id)

      overlays_by_id = payload[:fixed_charges].each_with_object({}) do |entry, acc|
        entry_hash = entry.to_h.with_indifferent_access
        id = entry_hash[:id]
        result.not_found_failure!(resource: "fixed_charge").raise_if_error! unless fixed_charges_by_id.key?(id)
        acc[id] = entry_hash.except(:id)
      end

      payload[:fixed_charges] = fixed_charges_by_id.values.map do |fc|
        {
          id: fc.id,
          charge_model: fc.charge_model,
          properties: fc.properties,
          units: fc.units,
          invoice_display_name: fc.invoice_display_name,
          pay_in_advance: fc.pay_in_advance,
          prorated: fc.prorated
        }.with_indifferent_access.merge(overlays_by_id[fc.id] || {})
      end

      payload
    end

    def valid?(args)
      result.payment_method = payment_method

      Subscriptions::ValidateService.new(result, **args).valid?
    end

    def payment_method
      return @payment_method if defined? @payment_method
      return nil if params[:payment_method].blank? || params[:payment_method][:payment_method_id].blank?

      @payment_method = PaymentMethod.find_by(id: params[:payment_method][:payment_method_id], organization_id: subscription.organization_id)
    end
  end
end
