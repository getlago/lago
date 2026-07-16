# frozen_string_literal: true

module Invoices
  module Preview
    class SubscriptionPlanChangeService < BaseService
      Result = BaseResult[:subscriptions]

      def initialize(current_subscription:, target_plan_code:)
        @current_subscription = current_subscription
        @target_plan_code = target_plan_code
        super
      end

      def call
        return result.not_found_failure!(resource: "subscription") unless current_subscription
        return result.not_found_failure!(resource: "plan") unless target_plan

        if target_plan.id == current_subscription.plan_id
          return result.single_validation_failure!(
            error_code: "new_plan_should_be_different_from_existing_plan"
          )
        end

        result.subscriptions = [
          terminated_current_subscription,
          (new_subscription if target_plan.pay_in_advance?)
        ].compact

        result
      end

      private

      attr_reader :current_subscription, :target_plan_code

      delegate :organization, :customer, to: :current_subscription

      def terminated_current_subscription
        current_subscription.terminated_at = termination_date
        current_subscription.status = :terminated

        current_subscription.next_subscriptions.build(
          **new_subscription.attributes
        )

        current_subscription
      end

      def new_subscription
        @new_subscription ||= Subscription.new(
          organization_id: organization.id,
          customer:,
          plan: target_plan,
          name: target_plan.name,
          external_id: current_subscription.external_id,
          previous_subscription_id: current_subscription.id,
          subscription_at: current_subscription.subscription_at,
          billing_time: current_subscription.billing_time,
          ending_at: current_subscription.ending_at,
          status: :active,
          started_at: new_subscription_started_at,
          created_at: Time.current
        )
      end

      def new_subscription_started_at
        return Time.current if upgrade?

        date_service.next_period_started_at
      end

      def termination_date
        return Time.current if upgrade?

        date_service.end_of_period + 1.day
      end

      def date_service
        @date_service ||= Subscriptions::DatesService
          .new_instance(current_subscription, Time.current, current_usage: true)
      end

      def upgrade?
        target_plan.yearly_amount_cents >= current_subscription.plan.yearly_amount_cents
      end

      def target_plan
        @target_plan ||= organization.plans.parents.find_by(code: target_plan_code)
      end
    end
  end
end
