# frozen_string_literal: true

module Subscriptions
  class PlanUpgradeService < BaseService
    include Subscriptions::Concerns::BillingEntityResolutionConcern

    Result = BaseResult[:subscription]

    def initialize(current_subscription:, plan:, params:)
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

        new_subscription = new_subscription_with_overrides

        cancel_pending_subscription if pending_subscription?

        new_subscription.pending!

        apply_activation_rules(new_subscription) if params[:activation_rules].present?

        Subscriptions::ActivateService.call!(subscription: new_subscription)

        result.subscription = new_subscription
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    end

    private

    attr_reader :current_subscription, :plan, :params, :name

    def new_subscription_with_overrides
      resolved_entity = resolve_billing_entity(organization: current_subscription.organization, params:)
      new_subscription = Subscription.new(
        organization_id: current_subscription.customer.organization_id,
        customer: current_subscription.customer,
        plan: params.key?(:plan_overrides) ? override_plan : plan,
        name:,
        external_id: current_subscription.external_id,
        previous_subscription_id: current_subscription.id,
        subscription_at: current_subscription.subscription_at,
        billing_time: current_subscription.billing_time,
        ending_at: params.key?(:ending_at) ? params[:ending_at] : current_subscription.ending_at,
        consolidate_invoice: params.key?(:consolidate_invoice) ? params[:consolidate_invoice] : current_subscription.consolidate_invoice,
        billing_entity_id: resolved_entity&.id || current_subscription.billing_entity_id
      )

      if params.key?(:payment_method)
        new_subscription.payment_method_type = params[:payment_method][:payment_method_type] if params[:payment_method].key?(:payment_method_type)
        new_subscription.payment_method_id = params[:payment_method][:payment_method_id] if params[:payment_method].key?(:payment_method_id)
      end

      new_subscription
    end

    def update_pending_subscription
      current_subscription.plan = plan
      current_subscription.name = name if name.present?
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
