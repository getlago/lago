# frozen_string_literal: true

module Invoices
  class RegenerateFromVoidedService < BaseService
    Result = BaseResult[:invoice]

    def initialize(voided_invoice:, fees_params:)
      @voided_invoice = voided_invoice
      @fees_params = fees_params
      @regenerated_invoice = nil
      super
    end

    activity_loggable(
      action: "invoice.regenerated",
      record: -> { voided_invoice }
    )

    def call
      return result.not_found_failure!(resource: "invoice") unless voided_invoice

      ActiveRecord::Base.transaction do
        create_regenerated_invoice
        create_invoice_subscriptions
        process_fees
        adjust_fees
        assign_applied_usage_thresholds
        Invoices::ApplyInvoiceCustomSectionsService.call!(invoice: regenerated_invoice)
        regenerated_invoice.fees_amount_cents = regenerated_invoice.fees.sum(:amount_cents)
        regenerated_invoice.sub_total_excluding_taxes_amount_cents = regenerated_invoice.fees.sum(:amount_cents)

        # apply taxes credits and coupons
        Credits::ProgressiveBillingService.call!(invoice: regenerated_invoice)
        Credits::AppliedCouponsService.call!(invoice: regenerated_invoice) if should_create_coupon_credit?
        totals_result = Invoices::ComputeTaxesAndTotalsService.call(invoice: regenerated_invoice, finalizing: true)

        # We intentionally return early from the transaction block if tax computation fails this is an async call,
        # we still want to persist the regenerated invoice in its current state it will be finalized later when
        # we get the taxes back check Invoices::ProviderTaxes::PullTaxesAndApplyJob.perform_later(invoice:)
        if !totals_result.success? && regenerated_invoice.tax_status == "pending"
          result.invoice = regenerated_invoice
          return result # rubocop:disable Rails/TransactionExitStatement
        end

        create_credit_note_credit if should_create_credit_note_credit?
        create_applied_prepaid_credit if should_create_applied_prepaid_credit?
        regenerated_invoice.payment_status = regenerated_invoice.total_amount_cents.positive? ? :pending : :succeeded
        Invoices::TransitionToFinalStatusService.call!(invoice: regenerated_invoice)
        regenerated_invoice.save!
      end

      result.invoice = regenerated_invoice

      call_invoice_finalization_jobs(regenerated_invoice)

      result
    end

    private

    attr_accessor :regenerated_invoice
    attr_reader :voided_invoice, :fees_params

    delegate :customer, to: :voided_invoice

    def should_create_credit_note_credit?
      return false unless regenerated_invoice.total_amount_cents&.positive?

      true
    end

    def should_create_coupon_credit?
      return false unless regenerated_invoice.fees_amount_cents&.positive?

      true
    end

    def should_create_applied_prepaid_credit?
      regenerated_invoice.total_amount_cents&.positive? && wallets.any?
    end

    def wallets
      @wallets ||= voided_invoice.customer.wallets.active.with_positive_balance
    end

    def create_applied_prepaid_credit
      prepaid_credit_result = Credits::AppliedPrepaidCreditsService.call!(invoice: regenerated_invoice)
      refresh_amounts(credit_amount_cents: prepaid_credit_result.prepaid_credit_amount_cents)
    end

    def create_credit_note_credit
      credit_result = Credits::CreditNoteService.new(invoice: regenerated_invoice).call!

      refresh_amounts(credit_amount_cents: credit_result.credits.sum(&:amount_cents)) if credit_result.credits
    end

    def refresh_amounts(credit_amount_cents:)
      regenerated_invoice.total_amount_cents -= credit_amount_cents
    end

    def adjust_fees
      subunit = regenerated_invoice.total_amount.currency.subunit_to_unit

      regenerated_invoice.fees.each do |fee|
        adjusted_fee = fee.adjusted_fee
        next unless adjusted_fee

        if fee.fee_type == "charge"
          properties = fee.charge_filter&.properties || fee.charge.properties

          result = Fees::InitFromAdjustedChargeFeeService.call!(
            adjusted_fee:,
            boundaries: fee.properties,
            properties:
          )

          updated = result.fee
          fee.assign_attributes(
            updated.attributes.slice(
              "invoice_display_name",
              "charge_id",
              "subscription_id",
              "units",
              "unit_amount_cents",
              "precise_unit_amount",
              "amount_cents",
              "precise_amount_cents",
              "amount_details",
              "charge_filter"
            )
          )
        elsif fee.fee_type == "fixed_charge"
          result = Fees::InitFromAdjustedFixedChargeFeeService.call!(
            adjusted_fee:,
            boundaries: fee.properties,
            properties: fee.fixed_charge.properties
          )

          updated = result.fee
          fee.assign_attributes(
            updated.attributes.slice(
              "invoice_display_name",
              "fixed_charge_id",
              "subscription_id",
              "units",
              "unit_amount_cents",
              "precise_unit_amount",
              "amount_cents",
              "precise_amount_cents",
              "amount_details"
            )
          )
        else
          fee.invoice_display_name = adjusted_fee.invoice_display_name if adjusted_fee.invoice_display_name.present?
          fee.charge_id = adjusted_fee.charge_id if adjusted_fee.charge_id.present?
          fee.subscription_id = adjusted_fee.subscription_id if adjusted_fee.subscription_id.present?
          fee.units = adjusted_fee.units if adjusted_fee.units.present?

          units = fee.units.to_d

          if adjusted_fee.adjusted_units?
            unit_cents = fee.unit_amount_cents
            amount_cents = (units * unit_cents).round
            precise_unit_amount = unit_cents.to_f / subunit
          else
            unit_cents = adjusted_fee.unit_precise_amount_cents
            amount_cents = (units * unit_cents).round
            precise_unit_amount = unit_cents / subunit
          end

          fee.unit_amount_cents = unit_cents.round
          fee.precise_unit_amount = precise_unit_amount
          fee.amount_cents = amount_cents
          fee.precise_amount_cents = units * unit_cents
        end

        fee.save!
      end
    end

    def assign_applied_usage_thresholds
      return unless voided_invoice.progressive_billing?

      voided_invoice.applied_usage_thresholds.find_each do |applied_usage_threshold|
        applied_usage_threshold.dup.tap do |duplicate|
          duplicate.invoice = regenerated_invoice
          duplicate.save!
        end
      end
    end

    def voided_invoice_fees
      @voided_invoice_fees ||= voided_invoice.fees.where(id: fees_params.map { |fee| fee[:id] }.compact).index_by(&:id)
    end

    def process_fees
      fees_params.each do |fee_params|
        if fee_params[:id].present?
          voided_fee = voided_invoice_fees[fee_params[:id]]
          dup_fee = duplicate_fee(voided_fee, fee_params) if voided_fee
        end

        adjusted_fee_params = {
          invoice_display_name: fee_params[:invoice_display_name],
          units: fee_params[:units],
          charge_id: fee_params[:charge_id],
          charge_filter_id: fee_params[:charge_filter_id],
          subscription_id: fee_params[:subscription_id]
        }
        adjusted_fee_params[:unit_precise_amount] = fee_params[:unit_amount_cents] if fee_params[:unit_amount_cents].present?
        adjusted_fee_params[:fee_id] = dup_fee.id if dup_fee

        AdjustedFees::CreateService.call(
          invoice: regenerated_invoice,
          params: adjusted_fee_params,
          regenerating_voided: true
        )
      end
    end

    def duplicate_fee(voided_fee, fee_params)
      dup_fee = voided_fee.dup
      dup_fee.invoice = regenerated_invoice
      dup_fee.payment_status = :pending
      dup_fee.taxes_amount_cents = 0
      dup_fee.taxes_precise_amount_cents = 0
      dup_fee.precise_coupons_amount_cents = 0
      dup_fee.taxes_base_rate = 0
      dup_fee.taxes_rate = 0
      dup_fee.original_fee = voided_fee.original_fee || voided_fee
      dup_fee.save!

      return dup_fee if adjusting_units?(voided_fee, fee_params)

      voided_fee.presentation_breakdowns.each do |breakdown|
        dup_fee.presentation_breakdowns.create!(
          organization_id: breakdown.organization_id,
          presentation_by: breakdown.presentation_by,
          units: breakdown.units
        )
      end

      dup_fee
    end

    def adjusting_units?(voided_fee, fee_params)
      return true if fee_params[:units].blank?

      BigDecimal(fee_params[:units].to_s) != voided_fee.units
    end

    def create_invoice_subscriptions
      voided_invoice.invoice_subscriptions.each do |subscription|
        subscription.update!(regenerated_invoice_id: regenerated_invoice.id)

        subscription.dup.tap do |dup|
          dup.invoice = regenerated_invoice
          dup.regenerated_invoice_id = nil
          dup.save!
        end
      end
    end

    def create_regenerated_invoice
      @regenerated_invoice = Invoices::CreateGeneratingService.call!(
        customer: voided_invoice.customer,
        invoice_type: voided_invoice.invoice_type,
        currency: voided_invoice.currency,
        datetime: voided_invoice.created_at,
        billing_entity: voided_invoice.billing_entity
      ).invoice.tap do |invoice|
        invoice.update!(voided_invoice_id: voided_invoice.id)
      end
    end

    def call_invoice_finalization_jobs(invoice)
      return if invoice.closed?

      Utils::SegmentTrack.invoice_created(invoice)
      SendWebhookJob.perform_later("invoice.created", invoice)
      Utils::ActivityLog.produce(invoice, "invoice.created")
      GenerateDocumentsJob.perform_later(invoice:, notify: should_deliver_email?)
      Integrations::Aggregator::Invoices::CreateJob.perform_later(invoice:) if invoice.should_sync_invoice?
      Integrations::Aggregator::Invoices::Hubspot::CreateJob.perform_later(invoice:) if invoice.should_sync_hubspot_invoice?
      Invoices::Payments::CreateService.call_async(invoice:)
    end

    def should_deliver_email?
      License.premium? && regenerated_invoice.billing_entity.email_settings.include?("invoice.finalized")
    end
  end
end
