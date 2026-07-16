# frozen_string_literal: true

module CreditNotes
  class CreateFromTermination < BaseService
    Result = CreditNotes::CreateService::Result

    # on_termination controls what to do with the unused subscription amount:
    #   :credit - credits all unused amount back to the customer
    #   :refund - refunds the unused paid amount, credits any updaid unused amount back to the customer
    #   :offset - refunds the unused paid amount, offsets the invoice by the updaid unused amount
    def initialize(subscription:, reason: "order_change", upgrade: false, context: nil, on_termination: :credit)
      @subscription = subscription
      @reason = reason
      @upgrade = upgrade
      @context = context
      @on_termination = on_termination

      super
    end

    def call
      return result if (last_subscription_fee&.amount_cents || 0).zero? || last_subscription_fee.invoice.voided?

      raise NotImplementedError, "Upgrade and refund are not supported together" if upgrade && refund?
      raise NotImplementedError, "Upgrade and offset are not supported together" if upgrade && offset?

      base_creditable_amount = calculate_base_creditable_amount

      return result if base_creditable_amount.zero?

      credit_amount_cents, refund_amount_cents, offset_amount_cents = calculate_amounts(base_creditable_amount)

      return result if (credit_amount_cents + refund_amount_cents + offset_amount_cents).zero?

      CreditNotes::CreateService.call(
        invoice: last_subscription_fee.invoice,
        credit_amount_cents:,
        refund_amount_cents:,
        offset_amount_cents:,
        items: [
          {
            fee_id: last_subscription_fee.id,
            amount_cents: base_creditable_amount.truncate(CreditNote::DB_PRECISION_SCALE)
          }
        ],
        reason: reason.to_sym,
        automatic: true,
        context:
      )
    end

    private

    attr_accessor :subscription, :reason, :context, :on_termination, :upgrade

    delegate :plan, :terminated_at, :customer, to: :subscription

    def refund?
      on_termination == :refund
    end

    def offset?
      on_termination == :offset
    end

    def calculate_base_creditable_amount
      amount = calculate_base_unused_amount
      return 0 unless amount.positive?

      # NOTE: In some cases, if the fee was already prorated (in case of multiple upgrade) the amount
      #       could be greater than the last subscription fee amount.
      #       In that case, we have to use the last subscription fee amount
      amount = last_subscription_fee.amount_cents if amount > last_subscription_fee.amount_cents

      # NOTE: if credit notes were already issued on the fee,
      #       we have to deduct them from the prorated amount
      amount -= last_subscription_fee.credit_note_items.sum(:amount_cents)
      return 0 unless amount.positive?

      amount
    end

    def last_subscription_fee
      @last_subscription_fee ||= subscription.last_subscription_fee
    end

    def calculate_base_unused_amount
      day_price * remaining_duration
    end

    def date_service
      @date_service ||= Subscriptions::DatesService.new_instance(
        subscription,
        terminated_at
      )
    end

    def plan_amount_cents
      last_subscription_fee&.amount_details&.[]("plan_amount_cents") || plan.amount_cents
    end

    def next_end_of_period
      date_service.next_end_of_period.to_date
    end

    def day_price
      date_service.single_day_price(plan_amount_cents:)
    end

    def terminated_at_in_timezone
      terminated_at.in_time_zone(customer.applicable_timezone)
    end

    def remaining_duration
      billed_from = terminated_at_in_timezone.end_of_day.utc.to_date
      billed_from -= 1.day if upgrade

      if plan.has_trial? && subscription.trial_end_date >= billed_from
        billed_from = if subscription.trial_end_date > next_end_of_period
          next_end_of_period
        else
          subscription.trial_end_date - 1.day
        end
      end

      duration = (next_end_of_period - billed_from).to_i

      duration.negative? ? 0 : duration
    end

    def calculate_amounts(base_creditable_amount)
      # Calculate the total creditable amount (including taxes)
      total_creditable_amount = adjust_for_coupon_and_taxes(base_creditable_amount)

      refund_amount_cents = calculate_refund(total_creditable_amount)
      creditable_amount_cents = total_creditable_amount - refund_amount_cents

      # [credit_amount, refund_amount, offset_amount]
      case on_termination
      when :credit
        [total_creditable_amount, 0, 0]
      when :refund
        [creditable_amount_cents, refund_amount_cents, 0]
      when :offset
        [0, refund_amount_cents, creditable_amount_cents]
      end
    end

    def adjust_for_coupon_and_taxes(item_amount)
      precise_amount_cents = item_amount.truncate(CreditNote::DB_PRECISION_SCALE)
      item = CreditNoteItem.new(fee_id: last_subscription_fee.id, precise_amount_cents:)
      taxes_result = CreditNotes::ApplyTaxesService.call(invoice: last_subscription_fee.invoice, items: [item])

      (
        precise_amount_cents -
        taxes_result.coupons_adjustment_amount_cents +
        taxes_result.precise_taxes_amount_cents
      ).round
    end

    def calculate_refund(total_creditable_amount)
      potential_refund = paid_amount_prorated_to_subscription - creditable_used_amount

      return 0 if potential_refund <= 0

      # The refund cannot exceed the creditable amount
      refund_amount_cents = [potential_refund, total_creditable_amount].min
      refund_amount_cents.round
    end

    def credit_only?
      !refund
    end

    def creditable_used_amount
      adjust_for_coupon_and_taxes(base_subscription_used_amount)
    end

    def paid_amount_prorated_to_subscription
      invoice_amount = last_subscription_fee.invoice.sub_total_including_taxes_amount_cents

      return 0 if invoice_amount.zero?

      fee_amount = last_subscription_fee.sub_total_excluding_taxes_precise_amount_cents + last_subscription_fee.taxes_precise_amount_cents
      fee_rate = fee_amount.fdiv(invoice_amount)
      paid_amount = last_subscription_fee.invoice.total_paid_amount_cents

      fee_rate * paid_amount
    end

    def base_subscription_used_amount
      day_price * used_duration
    end

    def used_duration
      billed_from = date_service.from_datetime.to_date

      # If there's a trial, adjust the billing start to after the trial
      if plan.has_trial? && subscription.trial_end_date
        trial_end = subscription.trial_end_date.to_date
        billed_from = trial_end if trial_end > billed_from
      end

      billed_to = terminated_at_in_timezone.end_of_day.utc.to_date

      # TODO:Could it happen that terminated_at is within the next billing period here ?
      billed_to = next_end_of_period if billed_to > next_end_of_period

      duration = (billed_to - billed_from).to_i + 1
      duration.negative? ? 0 : duration
    end
  end
end
