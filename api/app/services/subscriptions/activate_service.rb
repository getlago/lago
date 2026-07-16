# frozen_string_literal: true

module Subscriptions
  class ActivateService < BaseService
    Result = BaseResult[:subscription]

    def initialize(subscription:, timestamp: Time.current)
      @subscription = subscription
      @timestamp = timestamp
      super
    end

    def call
      return result if subscription.active?
      return result if subscription.gated?

      ActiveRecord::Base.transaction do
        ActivationRules::EvaluateService.call!(subscription:) if subscription.pending?

        if subscription.pending? && subscription.pending_rules?
          gate_subscription
        else
          activate_subscription
        end
      end

      result.subscription = subscription
      result
    end

    private

    attr_reader :subscription, :timestamp

    def gate_subscription
      subscription.mark_as_incomplete!(timestamp)

      emit_fixed_charge_events

      after_commit do
        bill_subscription(skip_charges: true) if subscription.payment_gated?

        SendWebhookJob.perform_later("subscription.incomplete", subscription)
        Utils::ActivityLog.produce(subscription, "subscription.incomplete")
      end
    end

    def activate_subscription
      return if subscription.incomplete? && subscription.activation_rules.rejected.exists?

      if upgrade?
        activate_for_upgrade
      elsif downgrade?
        activate_for_downgrade
      else
        activate_standalone
      end
    end

    def activate_for_upgrade
      from_incomplete = subscription.incomplete?
      billed_during_gating = from_incomplete && subscription.activation_rules.payment.any?
      previous_subscription = subscription.previous_subscription

      Subscriptions::TerminateService.call(
        subscription: previous_subscription,
        upgrade: true
      )

      subscription.mark_as_active!(timestamp)

      billable_subscriptions = [previous_subscription]

      emit_fixed_charge_events unless from_incomplete

      unless billed_during_gating
        billable_subscriptions << subscription if subscription.fixed_charges.pay_in_advance.any? ||
          (subscription.plan.pay_in_advance? && !subscription.in_trial_period?)
      end

      after_commit do
        notify_started
        enqueue_gating_catch_up_jobs if from_incomplete
      end

      bill_rotation_subscriptions(
        billable_subscriptions,
        billing_at: Time.current + 1.second,
        non_invoiceable_subscriptions: billable_subscriptions
      )
    end

    def activate_for_downgrade
      from_incomplete = subscription.incomplete?
      billed_during_gating = from_incomplete && subscription.activation_rules.payment.any?
      previous_subscription = subscription.previous_subscription

      previous_subscription.mark_as_terminated!(timestamp)

      subscription.mark_as_active!(timestamp)

      billable_subscriptions = [previous_subscription]

      emit_fixed_charge_events unless from_incomplete

      unless billed_during_gating
        billable_subscriptions << subscription if subscription.fixed_charges.pay_in_advance.any? || subscription.plan.pay_in_advance?
      end

      after_commit do
        SendWebhookJob.perform_later("subscription.terminated", previous_subscription)
        Utils::ActivityLog.produce(previous_subscription, "subscription.terminated")

        if previous_subscription.should_sync_hubspot_subscription?
          Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob.perform_later(subscription: previous_subscription)
        end

        notify_started
        enqueue_gating_catch_up_jobs if from_incomplete
      end

      bill_rotation_subscriptions(billable_subscriptions, billing_at: timestamp)
    end

    def activate_standalone
      from_incomplete = subscription.incomplete?

      subscription.mark_as_active!(timestamp)

      emit_fixed_charge_events unless from_incomplete

      after_commit do
        if from_incomplete
          bill_subscription if subscription.activation_rules.payment.none?
          enqueue_gating_catch_up_jobs
        else
          bill_subscription(skip_charges: true)
        end

        notify_started
      end
    end

    def bill_rotation_subscriptions(billable_subscriptions, billing_at:, non_invoiceable_subscriptions: [subscription.previous_subscription])
      after_commit do
        BillSubscriptionJob.perform_later(billable_subscriptions, billing_at.to_i, invoicing_reason: :upgrading)
        BillNonInvoiceableFeesJob.perform_later(non_invoiceable_subscriptions, billing_at)
      end
    end

    def enqueue_gating_catch_up_jobs
      return unless subscription.activation_rules.payment.any?

      ActivationRules::BillFixedChargesDeltaJob.perform_later(subscription)

      unless subscription.previous_subscription
        ActivationRules::BillMissedPeriodsJob.perform_later(subscription)
      end
    end

    def notify_started
      SendWebhookJob.perform_later("subscription.started", subscription)
      Utils::ActivityLog.produce(subscription, "subscription.started")

      return unless subscription.should_sync_hubspot_subscription?

      Integrations::Aggregator::Subscriptions::Hubspot::CreateJob.perform_later(subscription:)
    end

    def emit_fixed_charge_events
      EmitFixedChargeEventsService.call!(
        subscriptions: [subscription],
        timestamp: subscription.started_at + 1.second
      )
    end

    def bill_subscription(skip_charges: false)
      invoicing_reason = if upgrade? || downgrade?
        :upgrading
      else
        :subscription_starting
      end

      if subscription.plan.pay_in_advance? && !subscription.in_trial_period?
        BillSubscriptionJob.perform_later(
          [subscription],
          timestamp.to_i,
          invoicing_reason:,
          skip_charges:
        )
      elsif subscription.fixed_charges.pay_in_advance.any?
        Invoices::CreatePayInAdvanceFixedChargesJob.perform_later(
          subscription,
          subscription.started_at + 1.second
        )
      end
    end

    def upgrade?
      return false unless subscription.previous_subscription
      return false if subscription.plan.id == subscription.previous_subscription.plan.id

      subscription.plan.yearly_amount_cents >= subscription.previous_subscription.plan.yearly_amount_cents
    end

    def downgrade?
      return false unless subscription.previous_subscription
      return false if subscription.plan.id == subscription.previous_subscription.plan.id

      subscription.plan.yearly_amount_cents < subscription.previous_subscription.plan.yearly_amount_cents
    end
  end
end
