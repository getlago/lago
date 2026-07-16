# frozen_string_literal: true

module Commitments
  module Minimum
    class CalculateTrueUpFeeService < BaseService
      Result = BaseResult[:amount_cents, :commitment_amount_cents, :precise_amount_cents]

      def self.new_instance(invoice_subscription:)
        klass = if invoice_subscription.subscription.plan.pay_in_advance?
          Commitments::Minimum::InAdvance::CalculateTrueUpFeeService
        else
          Commitments::Minimum::InArrears::CalculateTrueUpFeeService
        end

        klass.new(invoice_subscription:)
      end

      def initialize(invoice_subscription:)
        @invoice_subscription = invoice_subscription
        @minimum_commitment = invoice_subscription.subscription.plan.minimum_commitment

        super
      end

      def call
        result.amount_cents = amount_cents
        result.precise_amount_cents = precise_amount_cents
        result
      end

      private

      attr_reader :minimum_commitment, :invoice_subscription

      delegate :subscription, to: :invoice_subscription

      def amount_cents
        return 0 if !minimum_commitment || fees_total_amount_cents >= commitment_amount_cents

        commitment_amount_cents - fees_total_amount_cents
      end

      def precise_amount_cents
        return 0.to_d if !minimum_commitment || fees_total_precise_amount_cents >= commitment_amount_cents

        commitment_amount_cents - fees_total_precise_amount_cents
      end

      def fees_total_amount_cents
        subscription_fees.sum(:amount_cents) +
          charge_fees.sum(:amount_cents) +
          charge_in_advance_fees.sum(:amount_cents) +
          charge_in_advance_recurring_fees.sum(:amount_cents) +
          fixed_charge_fees.sum(:amount_cents) +
          fixed_charge_in_advance_fees.sum(:amount_cents)
      end

      def fees_total_precise_amount_cents
        subscription_fees.sum(:precise_amount_cents) +
          charge_fees.sum(:precise_amount_cents) +
          charge_in_advance_fees.sum(:precise_amount_cents) +
          charge_in_advance_recurring_fees.sum(:precise_amount_cents) +
          fixed_charge_fees.sum(:precise_amount_cents) +
          fixed_charge_in_advance_fees.sum(:precise_amount_cents)
      end

      def commitment_amount_cents
        result = Commitments::CalculateAmountService.call(
          commitment: minimum_commitment,
          invoice_subscription:
        )

        result.commitment_amount_cents
      end
    end
  end
end
