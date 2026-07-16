# frozen_string_literal: true

module Subscriptions
  class TerminateService < BaseService
    Result = BaseResult[:subscription]

    def initialize(subscription:, async: true, upgrade: false, on_termination_credit_note: subscription&.on_termination_credit_note, on_termination_invoice: subscription&.on_termination_invoice)
      @subscription = subscription
      @async = async
      @upgrade = upgrade
      @on_termination_credit_note = on_termination_credit_note.blank? ? :credit : on_termination_credit_note.to_sym
      @on_termination_invoice = on_termination_invoice.blank? ? :generate : on_termination_invoice.to_sym

      super
    end

    def call
      return result.not_found_failure!(resource: "subscription") if subscription.blank?
      return result.single_validation_failure!(error_code: "subscription_incomplete") if subscription.incomplete?
      return result.single_validation_failure!(error_code: "next_subscription_incomplete") if !upgrade && subscription.next_subscription&.incomplete?

      ActiveRecord::Base.transaction do
        if subscription.pending?
          previous = subscription.previous_subscription
          subscription.mark_as_canceled!

          if previous
            SendWebhookJob.perform_after_commit("subscription.updated", previous)
            Utils::ActivityLog.produce_after_commit(previous, "subscription.updated")
          end
        elsif !subscription.terminated?
          subscription.mark_as_terminated!
          update_on_termination_actions!

          if subscription.should_sync_hubspot_subscription?
            Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob.perform_after_commit(subscription:)
          end

          if generate_credit_note_for_unconsumed_subscription?
            # NOTE: As subscription was payed in advance and terminated before the end of the period,
            #       we have to create a credit note for the days that were not consumed.
            #       Depending on the termination behaviour, we will optionally refund the portion of the unconsumed
            #       subscription that was already paid.

            if blocked_by_pending_taxes?
              result.not_allowed_failure!(code: "cannot_terminate_with_pending_taxes")
              result.raise_if_error!
            end

            CreditNotes::CreateFromTermination.call!(
              subscription:,
              reason: "order_cancellation",
              upgrade: upgrade,
              on_termination: on_termination_credit_note
            )
          end

          # NOTE: We should bill subscription and generate invoice for all cases except for the upgrade
          #       For upgrade we will create only one invoice for termination charges and for in advance charges
          #       It is handled in subscriptions/create_service.rb
          bill_subscription unless upgrade
        end

        cancel_next_subscription
      end

      SendWebhookJob.perform_after_commit("subscription.terminated", subscription)
      Utils::ActivityLog.produce_after_commit(subscription, "subscription.terminated")

      result.subscription = subscription
      result
    rescue BaseService::FailedResult => e
      e.result
    end

    # NOTE: Called to terminate a downgraded subscription
    def terminate_and_start_next(timestamp:)
      next_subscription = subscription.next_subscription
      return result unless next_subscription
      return result unless next_subscription.pending?

      activation_result = Subscriptions::ActivateService.call!(
        subscription: next_subscription,
        timestamp: Time.zone.at(timestamp)
      )

      result.subscription = activation_result.subscription
      result
    end

    private

    attr_reader :subscription, :async, :upgrade, :on_termination_credit_note, :on_termination_invoice

    def cancel_next_subscription
      # NOTE: Upgrade path: next_subscription is the new subscription we just persisted, not a stale scheduled change
      return if upgrade

      next_subscription = subscription.next_subscription
      return if next_subscription.nil?

      next_subscription.mark_as_canceled!
    end

    def bill_subscription
      if bill_in_arrears_fees?
        if async
          BillSubscriptionJob.perform_after_commit(
            [subscription],
            subscription.terminated_at,
            invoicing_reason: :subscription_terminating
          )
        else
          BillSubscriptionJob.perform_now(
            [subscription],
            subscription.terminated_at,
            invoicing_reason: :subscription_terminating
          )
        end
      end

      # We always bill pay-in-advance non-invoiceable charges unless it's an upgrade.
      if async
        BillNonInvoiceableFeesJob.perform_after_commit([subscription], subscription.terminated_at)
      else
        BillNonInvoiceableFeesJob.perform_now([subscription], subscription.terminated_at)
      end
    end

    # NOTE: If subscription is terminated automatically by setting ending_at, there is a chance that this service will
    #       be called before invoice for the period has been generated.
    #       In that case we do not want to issue a credit note.
    def pay_in_advance_invoice_issued?
      # Subscription duplicate is used in this logic so that special cases used for terminated subscription
      # can be avoided in boundaries calculation
      duplicate = subscription.dup.tap { |s| s.status = :active }
      beginning_of_period = beginning_of_period(duplicate)

      # If this is first period, pay in advance invoice is issued with creating subscription
      return true if beginning_of_period < duplicate.started_at

      dates_service = Subscriptions::DatesService.new_instance(
        duplicate,
        beginning_of_period,
        current_usage: false
      )

      boundaries = BillingPeriodBoundaries.new(
        from_datetime: dates_service.from_datetime,
        to_datetime: dates_service.to_datetime,
        charges_from_datetime: dates_service.charges_from_datetime,
        charges_to_datetime: dates_service.charges_to_datetime,
        charges_duration: dates_service.charges_duration_in_days,
        timestamp: beginning_of_period
      )

      InvoiceSubscription.matching?(subscription, boundaries, recurring: false)
    end

    def beginning_of_period(subscription_dup)
      dates_service = Subscriptions::DatesService.new_instance(
        subscription_dup,
        subscription.terminated_at,
        current_usage: false
      )

      dates_service.previous_beginning_of_period(current_period: true).to_datetime
    end

    def generate_credit_note_for_unconsumed_subscription?
      pay_in_advance? &&
        pay_in_advance_invoice_issued? &&
        on_termination_credit_note.in?(%i[credit refund offset])
    end

    def pay_in_advance?
      subscription.plan.pay_in_advance?
    end

    def pay_in_arrears?
      !pay_in_advance?
    end

    def bill_in_arrears_fees?
      on_termination_invoice == :generate
    end

    def update_on_termination_actions!
      params = {}
      params[:on_termination_credit_note] = on_termination_credit_note if pay_in_advance? && subscription.on_termination_credit_note != on_termination_credit_note
      params[:on_termination_invoice] = on_termination_invoice if subscription.on_termination_invoice != on_termination_invoice
      return if params.empty?

      Subscriptions::UpdateService.call!(subscription:, params:)
    end

    def blocked_by_pending_taxes?
      subscription.last_subscription_fee&.invoice&.tax_pending? || false
    end
  end
end
