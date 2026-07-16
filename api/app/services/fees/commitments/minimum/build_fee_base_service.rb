# frozen_string_literal: true

module Fees
  module Commitments
    module Minimum
      class BuildFeeBaseService < ::BaseService
        def initialize(invoice_subscription:)
          @invoice_subscription = invoice_subscription
          @minimum_commitment = invoice_subscription.subscription.plan.minimum_commitment

          super
        end

        private

        attr_reader :invoice_subscription, :minimum_commitment

        delegate :invoice, :subscription, to: :invoice_subscription
        delegate :organization, to: :invoice

        def pay_in_advance_first_period?
          subscription.plan.pay_in_advance? && !reconciliation_invoice_subscription
        end

        # Returns the invoice_subscription that represents the period being reconciled.
        # - For pay in arrears: the current invoice_subscription
        # - For pay in advance: the previous invoice_subscription (nil on first period)
        def reconciliation_invoice_subscription
          return @reconciliation_invoice_subscription if defined?(@reconciliation_invoice_subscription)

          @reconciliation_invoice_subscription = if subscription.plan.pay_in_advance?
            invoice_subscription.previous_invoice_subscription
          else
            invoice_subscription
          end
        end

        # Returns the billing period boundaries that the commitment fee covers.
        # These boundaries come directly from the invoice_subscription that represents
        # the period being reconciled, not from computed dates.
        def commitment_boundaries
          return {} unless reconciliation_invoice_subscription

          {
            "from_datetime" => reconciliation_invoice_subscription.from_datetime,
            "to_datetime" => reconciliation_invoice_subscription.to_datetime
          }
        end

        def build_fee(amount_cents:, precise_amount_cents:)
          precise_unit_amount = amount_cents / currency.subunit_to_unit.to_f

          Fee.new(
            invoice:,
            organization_id: organization.id,
            billing_entity_id: invoice.billing_entity_id,
            subscription:,
            fee_type: :commitment,
            invoiceable_type: "Commitment",
            invoiceable_id: minimum_commitment.id,
            amount_cents:,
            precise_amount_cents:,
            unit_amount_cents: amount_cents,
            precise_unit_amount:,
            amount_currency: subscription.plan.amount_currency,
            invoice_display_name: minimum_commitment.invoice_name,
            units: 1,
            taxes_amount_cents: 0,
            taxes_precise_amount_cents: 0.to_d,
            properties: commitment_boundaries
          )
        end

        def currency
          Money::Currency.new(subscription.plan.amount_currency)
        end
      end
    end
  end
end
