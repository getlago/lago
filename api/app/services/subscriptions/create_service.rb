# frozen_string_literal: true

module Subscriptions
  class CreateService < BaseService
    include Subscriptions::Concerns::BillingEntityResolutionConcern
    include Subscriptions::Concerns::FixedChargeUnitsOverrideDetectionConcern

    Result = BaseResult[:subscription, :payment_method]

    def initialize(customer:, plan:, params:)
      super

      @customer = customer
      @plan = plan
      @params = params

      @name = params[:name].to_s.strip
      @subscription_at = params[:subscription_at] || Time.current
      @billing_time = params[:billing_time]
      @external_id = params[:external_id].to_s.strip
      @plan_overrides = params[:plan_overrides].to_h.with_indifferent_access
    end

    def call
      return result unless valid?(
        customer:,
        plan:,
        subscription_at:,
        ending_at: params[:ending_at],
        payment_method: params[:payment_method],
        activation_rules: params[:activation_rules],
        subscription_type:
      )
      return result.forbidden_failure! if !License.premium? && params.key?(:plan_overrides)
      return result.validation_failure!(errors: {external_customer_id: ["value_is_mandatory"]}) if params[:external_customer_id].blank? && api_context?

      # TODO: Remove check we stop supporting `plan_overrides.usage_thresholds`
      if params[:usage_thresholds].present? && plan_overrides[:usage_thresholds].present?
        return result.validation_failure!(errors: {
          "plan_overrides.usage_thresholds": ["incompatible_params"],
          usage_thresholds: ["incompatible_params"]
        })
      end

      plan.amount_currency = plan_overrides[:amount_currency] if plan_overrides[:amount_currency]
      plan.amount_cents = plan_overrides[:amount_cents] if plan_overrides[:amount_cents]

      # NOTE: in API, it's possible to create a subscription for a new customer
      customer.save! if api_context?

      ActiveRecord::Base.transaction do
        Customers::UpdateCurrencyService
          .call(customer:, currency: plan.amount_currency)
          .raise_if_error!

        customer.with_lock do
          if customer.subscriptions.incomplete
              .exists?(["id = ? OR external_id = ?", params[:subscription_id], external_id])
            result.validation_failure!(errors: {subscription: ["subscription_incomplete"]})
            result.raise_if_error!
          end

          @current_subscription = editable_subscriptions
            .find_by("id = ? OR external_id = ?", params[:subscription_id], external_id)

          if current_subscription.nil? &&
              customer.organization.subscriptions.active.exists?(external_id:)
            result.validation_failure!(errors: {external_id: ["value_already_exist"]})
            result.raise_if_error!
          end

          subscription = handle_subscription

          if params[:usage_thresholds].present?
            UpdateUsageThresholdsService.call!(subscription:, usage_thresholds_params: params[:usage_thresholds], partial: false)
          end
          InvoiceCustomSections::AttachToResourceService.call(resource: subscription, params:) unless downgrade?

          result.subscription = subscription
        end
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ArgumentError
      result.validation_failure!(errors: {billing_time: ["value_is_invalid"]})
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :customer,
      :plan,
      :params,
      :name,
      :subscription_at,
      :billing_time,
      :external_id,
      :current_subscription,
      :plan_overrides

    def valid?(args)
      result.payment_method = payment_method

      Subscriptions::ValidateService.new(result, **args).valid?
    end

    def handle_subscription
      return upgrade_subscription if upgrade?
      return downgrade_subscription if downgrade?

      current_subscription || create_subscription
    end

    def upgrade?
      return false unless current_subscription
      return false if plan.id == current_subscription.plan.id

      plan.yearly_amount_cents >= current_subscription.plan.yearly_amount_cents
    end

    def downgrade?
      return false unless current_subscription
      return false if plan.id == current_subscription.plan.id

      plan.yearly_amount_cents < current_subscription.plan.yearly_amount_cents
    end

    def create_subscription
      new_subscription = Subscription.new(
        organization_id: customer.organization_id,
        customer:,
        plan: target_plan_for_new_subscription,
        subscription_at:,
        name:,
        external_id:,
        billing_time: billing_time || :calendar,
        ending_at: params[:ending_at],
        progressive_billing_disabled: params[:progressive_billing_disabled] || false,
        consolidate_invoice: params.key?(:consolidate_invoice) ? params[:consolidate_invoice] : true,
        billing_entity: resolve_billing_entity(organization: customer.organization, params:)
      )

      if params.key?(:payment_method)
        new_subscription.payment_method_type = params[:payment_method][:payment_method_type] if params[:payment_method].key?(:payment_method_type)
        new_subscription.payment_method_id = params[:payment_method][:payment_method_id] if params[:payment_method].key?(:payment_method_id)
      end

      if units_only_plan_overrides_change?
        new_subscription.status = :pending
        new_subscription.save!
        create_fixed_charge_units_overrides(new_subscription)
      end

      timezone = customer.applicable_timezone
      today = Time.current.in_time_zone(timezone).to_date
      subscription_date = new_subscription.subscription_at.in_time_zone(timezone).to_date

      if subscription_date == today
        handle_today_subscription(new_subscription)
      elsif subscription_date < today
        handle_past_subscription(new_subscription)
      else
        handle_future_subscription(new_subscription)
      end

      new_subscription
    end

    def handle_today_subscription(new_subscription)
      new_subscription.pending!
      apply_activation_rules(new_subscription)
      ActivateService.call!(
        subscription: new_subscription,
        timestamp: new_subscription.subscription_at
      )
    end

    def handle_past_subscription(new_subscription)
      new_subscription.mark_as_active!(new_subscription.subscription_at)

      EmitFixedChargeEventsService.call!(
        subscriptions: [new_subscription],
        timestamp: new_subscription.started_at + 1.second
      )

      after_commit do
        SendWebhookJob.perform_later("subscription.started", new_subscription)
        Utils::ActivityLog.produce(new_subscription, "subscription.started")

        if new_subscription.should_sync_hubspot_subscription?
          Integrations::Aggregator::Subscriptions::Hubspot::CreateJob.perform_later(subscription: new_subscription)
        end
      end
    end

    def handle_future_subscription(new_subscription)
      new_subscription.pending!
      apply_activation_rules(new_subscription)
    end

    def upgrade_subscription
      PlanUpgradeService.call!(current_subscription:, plan:, params:).subscription
    end

    def downgrade_subscription
      PlanDowngradeService.call!(customer:, current_subscription:, plan:, params:).subscription
    end

    def subscription_type
      return "downgrade" if downgrade?
      return "upgrade" if upgrade?

      "create"
    end

    def currency_missmatch?(old_plan, new_plan)
      return false unless old_plan

      old_plan.amount_currency != new_plan.amount_currency
    end

    def apply_activation_rules(subscription)
      return unless params[:activation_rules]&.present?

      Subscriptions::ActivationRules::ApplyService.call!(
        subscription:,
        activation_rules: params[:activation_rules]
      )
    end

    def editable_subscriptions
      return Subscription.none unless customer

      @editable_subscriptions ||= customer.subscriptions.active
        .or(customer.subscriptions.starting_in_the_future)
        .order(started_at: :desc)
    end

    def override_plan(plan)
      Plans::OverrideService.call(plan:, params: params[:plan_overrides].to_h.with_indifferent_access).plan
    end

    def target_plan_for_new_subscription
      return plan if units_only_plan_overrides_change?
      return override_plan(plan) if params.key?(:plan_overrides)

      plan
    end

    def units_only_plan_overrides_change?
      return @units_only_plan_overrides_change if defined?(@units_only_plan_overrides_change)

      @units_only_plan_overrides_change = !plan.parent_id &&
        params.key?(:plan_overrides) &&
        units_only_fixed_charges_plan_overrides?(params[:plan_overrides])
    end

    def create_fixed_charge_units_overrides(subscription)
      params[:plan_overrides][:fixed_charges].each do |entry|
        entry = entry.to_h.symbolize_keys

        fixed_charge = plan.fixed_charges.find_by(id: entry[:id])
        result.not_found_failure!(resource: "fixed_charge").raise_if_error! unless fixed_charge

        ::Subscription::FixedChargeUnitsOverride.create!(
          subscription:,
          fixed_charge:,
          organization: subscription.organization,
          units: entry[:units]
        )
      end
    end

    def payment_method
      return @payment_method if defined? @payment_method
      return nil if params[:payment_method].blank? || params[:payment_method][:payment_method_id].blank?

      @payment_method = PaymentMethod.find_by(id: params[:payment_method][:payment_method_id], organization_id: customer.organization_id)
    end
  end
end
