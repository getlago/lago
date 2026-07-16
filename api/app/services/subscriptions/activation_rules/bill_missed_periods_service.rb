# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class BillMissedPeriodsService < BaseService
      Result = BaseResult

      def initialize(subscription:)
        @subscription = subscription
        super
      end

      def call
        return result unless subscription.active?
        return result if subscription.previous_subscription
        return result unless subscription.activation_rules.payment.any?

        now = Time.current

        billing_at = period_end_at(subscription.started_at) + 1.second

        while billing_at <= now
          unless already_billed?(billing_at)
            BillSubscriptionJob.perform_later([subscription], billing_at.to_i, invoicing_reason: :subscription_periodic)
          end

          billing_at = period_end_at(billing_at) + 1.second
        end

        result
      end

      private

      attr_reader :subscription

      def already_billed?(billing_at)
        boundaries = Subscriptions::DatesService.new_instance(subscription, billing_at, current_usage: false)

        InvoiceSubscription.matching?(subscription, boundaries)
      end

      # Yearly and semiannual plans with monthly-billed charges or fixed charges
      # are billed by the clock at every monthly split boundary, not only at the
      # period end.
      def period_end_at(timestamp)
        dates = Subscriptions::DatesService.new_instance(subscription, timestamp, current_usage: true)

        if subscription.plan.charges_billed_in_monthly_split_intervals?
          dates.charges_to_datetime
        elsif subscription.plan.fixed_charges_billed_in_monthly_split_intervals?
          dates.fixed_charges_to_datetime
        else
          dates.end_of_period
        end
      end
    end
  end
end
