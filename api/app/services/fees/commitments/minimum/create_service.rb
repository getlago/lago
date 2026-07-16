# frozen_string_literal: true

module Fees
  module Commitments
    module Minimum
      class CreateService < BuildFeeBaseService
        def call
          return result if invoice_has_minimum_commitment_fee? || !minimum_commitment

          # For pay in advance plans, we reconcile the PREVIOUS billing period.
          # On the first invoice, there's no previous period to reconcile, so skip fee creation.
          return result if pay_in_advance_first_period?

          true_up_fee_result = ::Commitments::Minimum::CalculateTrueUpFeeService
            .new_instance(invoice_subscription:).call

          new_fee = build_fee(
            amount_cents: true_up_fee_result.amount_cents,
            precise_amount_cents: true_up_fee_result.precise_amount_cents
          )

          new_fee.save!
          result.fee = new_fee

          result
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        def invoice_has_minimum_commitment_fee?
          invoice.fees.commitment.where(subscription:).any? { |fee| fee.invoiceable.minimum_commitment? }
        end
      end
    end
  end
end
