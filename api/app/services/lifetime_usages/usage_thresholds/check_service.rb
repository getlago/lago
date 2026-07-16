# frozen_string_literal: true

module LifetimeUsages
  module UsageThresholds
    class CheckService < BaseService
      Result = BaseResult[:passed_thresholds]

      def initialize(lifetime_usage:, progressive_billed_amount: 0)
        @lifetime_usage = lifetime_usage
        @progressive_billed_amount = progressive_billed_amount
        @thresholds = lifetime_usage.subscription.applicable_usage_thresholds
        super
      end

      def call
        result.passed_thresholds = []
        return result unless thresholds.any?

        fixed_thresholds = thresholds.not_recurring.order(:amount_cents)
        # There is only 1 recurring threshold, `first` will return it or nil
        recurring_threshold = thresholds.recurring.first

        # Calculate the actual current usage, we need to substract the already progressively billed amount
        # as we might be passing the recurring threshold multiple times per period
        actual_current_usage = lifetime_usage.current_usage_amount_cents - progressive_billed_amount
        # we can end up in a situation where this goes below zero, in that case no thresholds are passed
        return result if actual_current_usage.negative?
        invoiced_usage = lifetime_usage.historical_usage_amount_cents + lifetime_usage.invoiced_usage_amount_cents + progressive_billed_amount

        # Get the largest threshold amount
        # in case there are no fixed_thresholds, this will return nil which to_i will convert to 0
        largest_threshold_amount = fixed_thresholds.maximum(:amount_cents).to_i
        total_usage = invoiced_usage + actual_current_usage

        # First check the fixed thresholds
        if invoiced_usage < largest_threshold_amount
          # we're below some thresholds, filter out those that we've already invoiced.
          # and keep those that we've passed based on total_usage.
          result.passed_thresholds += fixed_thresholds.select do |threshold|
            threshold.amount_cents > invoiced_usage && threshold.amount_cents <= total_usage
          end
          if recurring_threshold
            if total_usage - largest_threshold_amount >= recurring_threshold.amount_cents
              result.passed_thresholds << recurring_threshold
            end
          end
        elsif recurring_threshold
          recurring_remainder = invoiced_usage % recurring_threshold.amount_cents

          if actual_current_usage + recurring_remainder >= recurring_threshold.amount_cents
            result.passed_thresholds << recurring_threshold
          end
        end

        result
      end

      private

      attr_reader :lifetime_usage, :thresholds, :progressive_billed_amount
    end
  end
end
