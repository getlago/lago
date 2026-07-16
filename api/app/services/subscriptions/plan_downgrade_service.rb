# frozen_string_literal: true

module Subscriptions
  class PlanDowngradeService < BaseService
    include Subscriptions::Concerns::BillingEntityResolutionConcern

    Result = BaseResult[:subscription]

    def initialize(customer:, current_subscription:, plan:, params:)
      @customer = customer
      @current_subscription = current_subscription
      @plan = plan

      @params = params
      @name = params[:name].to_s.strip
      super
    end

    def call
      ActiveRecord::Base.transaction do
        if current_subscription.starting_in_the_future?
          apply_activation_rules(current_subscription) if params[:activation_rules]
          update_pending_subscription

          result.subscription = current_subscription
          return result
        end

        cancel_pending_subscription if pending_subscription?

        # NOTE: When downgrading a subscription, we keep the current one active
        #       until the next billing day. The new subscription will become active at this date
        new_sub = current_subscription.next_subscriptions.create!(
          organization_id: customer.organization_id,
          customer:,
          plan: params.key?(:plan_overrides) ? override_plan : plan,
          name:,
          external_id: current_subscription.external_id,
          subscription_at: current_subscription.subscription_at,
          status: :pending,
          billing_time: current_subscription.billing_time,
          ending_at: params.key?(:ending_at) ? params[:ending_at] : current_subscription.ending_at,
          progressive_billing_disabled: params[:progressive_billing_disabled] || false,
          consolidate_invoice: params.key?(:consolidate_invoice) ? params[:consolidate_invoice] : current_subscription.consolidate_invoice,
          billing_entity_id: current_subscription.billing_entity_id
        )

        apply_activation_rules(new_sub) if params[:activation_rules].present?

        if params[:billing_entity_id].present? || params[:billing_entity_code].present?
          override_entity = resolve_billing_entity(organization: current_subscription.organization, params:)
          new_sub.update!(billing_entity: override_entity) if override_entity
        end

        if params.key?(:payment_method)
          new_sub.payment_method_type = params[:payment_method][:payment_method_type] if params[:payment_method].key?(:payment_method_type)
          new_sub.payment_method_id = params[:payment_method][:payment_method_id] if params[:payment_method].key?(:payment_method_id)
          new_sub.save!
        end

        InvoiceCustomSections::AttachToResourceService.call(resource: new_sub, params:)

        after_commit do
          SendWebhookJob.perform_later("subscription.updated", current_subscription)
          Utils::ActivityLog.produce(current_subscription, "subscription.updated")
        end
      end

      result.subscription = current_subscription
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :customer, :current_subscription, :plan, :params, :name

    def update_pending_subscription
      current_subscription.plan = plan
      current_subscription.name = name if name.present?
      if params[:billing_entity_id].present? || params[:billing_entity_code].present?
        override_entity = resolve_billing_entity(organization: current_subscription.organization, params:)
        current_subscription.billing_entity = override_entity if override_entity
      end
      current_subscription.save!
    end

    def apply_activation_rules(subscription)
      Subscriptions::ActivationRules::ApplyService.call!(
        subscription:,
        activation_rules: params[:activation_rules]
      )
    end

    def override_plan
      Plans::OverrideService.call(plan:, params: params[:plan_overrides].to_h.with_indifferent_access).plan
    end

    def cancel_pending_subscription
      current_subscription.next_subscription.mark_as_canceled!
    end

    def pending_subscription?
      return false unless current_subscription.next_subscription

      current_subscription.next_subscription.pending?
    end
  end
end
