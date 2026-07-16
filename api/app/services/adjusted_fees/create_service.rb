# frozen_string_literal: true

module AdjustedFees
  class CreateService < BaseService
    Result = BaseResult[:fee, :adjusted_fee]

    # regenerating_voided - used when regenerating fees from a voided invoice into a new invoice (Invoices::RegenerateFromVoidedService);
    # if true, skips refreshing draft invoice and license check
    def initialize(invoice:, params:, regenerating_voided: false)
      @invoice = invoice
      @organization = invoice.organization
      @params = params
      @regenerating_voided = regenerating_voided

      super
    end

    def call
      return result.forbidden_failure! if forbidden?

      fee = find_or_create_fee
      return result unless result.success?
      return result.validation_failure!(errors: {adjusted_fee: ["already_exists"]}) if fee.adjusted_fee

      charge = fee.charge
      return result.validation_failure!(errors: {charge: ["invalid_charge_model"]}) if disabled_charge_model?(charge)

      unit_precise_amount_cents = params[:unit_precise_amount].to_f * fee.amount.currency.subunit_to_unit
      adjusted_fee = AdjustedFee.new(
        fee:,
        invoice: fee.invoice,
        subscription: fee.subscription,
        charge: fee.charge,
        fixed_charge: fee.fixed_charge,
        adjusted_units: params[:units].present? && params[:unit_precise_amount].blank?,
        adjusted_amount: params[:units].present? && params[:unit_precise_amount].present?,
        invoice_display_name: params[:invoice_display_name],
        fee_type: fee.fee_type,
        properties: fee.properties,
        units: params[:units].presence || 0,
        unit_amount_cents: unit_precise_amount_cents.round,
        unit_precise_amount_cents: unit_precise_amount_cents,
        grouped_by: fee.grouped_by,
        charge_filter: fee.charge_filter,
        organization:
      )
      adjusted_fee.save!

      subscription_id = fee.subscription_id
      charge_id = fee.charge_id
      fixed_charge_id = fee.fixed_charge_id
      charge_filter_id = fee.charge_filter_id

      unless regenerating_voided
        refresh_result = Invoices::RefreshDraftService.call(invoice: invoice)
        refresh_result.raise_if_error!
      end

      result.adjusted_fee = adjusted_fee.reload
      result.fee = if fixed_charge_id
        invoice.fees.find_by(subscription_id:, fixed_charge_id:)
      else
        invoice.fees.find_by(subscription_id:, charge_id:, charge_filter_id:)
      end
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :organization, :invoice, :params, :regenerating_voided

    def subscription
      @subscription ||= invoice.subscriptions.includes(plan: {charges: :filters, fixed_charges: nil}).find_by(id: params[:subscription_id])
    end

    def forbidden?
      return false if regenerating_voided

      !License.premium? || !invoice.draft?
    end

    def find_or_create_fee
      return find_existing_fee if params.key?(:fee_id)

      create_empty_fee
    end

    def find_existing_fee
      fee = invoice.fees.find_by(id: params[:fee_id])
      return result.not_found_failure!(resource: "fee") if fee.blank?

      fee
    end

    def create_empty_fee
      return result.not_found_failure!(resource: "subscription") unless subscription
      return create_empty_fee_for_fixed_charge if params[:fixed_charge_id].present?

      charge = subscription.plan.charges.find_by(id: params[:charge_id])
      return result.not_found_failure!(resource: "charge") unless charge

      if params[:charge_filter_id].present?
        charge_filter = charge.filters.find_by(id: params[:charge_filter_id])
        return result.not_found_failure!(resource: "charge_filter") unless charge_filter
      end

      fee = invoice.fees.find_by(
        subscription_id: subscription.id,
        charge_id: charge.id,
        charge_filter_id: params[:charge_filter_id]
      )
      fee || create_fee(subscription, charge, :charge)
    end

    def create_empty_fee_for_fixed_charge
      return result.not_found_failure!(resource: "subscription") unless subscription

      fixed_charge = subscription.plan.fixed_charges.find_by(id: params[:fixed_charge_id])
      return result.not_found_failure!(resource: "fixed_charge") unless fixed_charge

      fee = invoice.fees.find_by(
        subscription_id: subscription.id,
        fixed_charge_id: fixed_charge.id
      )
      fee || create_fee(subscription, fixed_charge, :fixed_charge)
    end

    def create_fee(subscription, chargeable, fee_type)
      invoice_subscription = invoice.invoice_subscriptions.find_by(subscription_id: subscription.id)

      Fee.create!(
        organization:,
        billing_entity_id: invoice.billing_entity_id,
        invoice:,
        subscription:,
        invoiceable: chargeable,
        charge: (chargeable if fee_type == :charge),
        fixed_charge: (chargeable if fee_type == :fixed_charge),
        charge_filter_id: params[:charge_filter_id],
        grouped_by: {},
        fee_type:,
        payment_status: :pending,
        events_count: 0,
        amount_currency: invoice.currency,
        amount_cents: 0,
        precise_amount_cents: 0.to_d,
        unit_amount_cents: 0,
        precise_unit_amount: 0.to_d,
        taxes_amount_cents: 0,
        taxes_precise_amount_cents: 0.to_d,
        units: 0,
        total_aggregated_units: 0,
        properties: fee_boundaries(invoice_subscription, fee_type)
      )
    end

    def fee_boundaries(invoice_subscription, fee_type)
      base = {timestamp: invoice_subscription.timestamp}

      if fee_type == :charge
        base.merge(
          charges_from_datetime: invoice_subscription.charges_from_datetime,
          charges_to_datetime: invoice_subscription.charges_to_datetime
        )
      else
        base.merge(
          fixed_charges_from_datetime: invoice_subscription.fixed_charges_from_datetime,
          fixed_charges_to_datetime: invoice_subscription.fixed_charges_to_datetime
        )
      end
    end

    def disabled_charge_model?(charge)
      return false unless charge
      return false unless unit_adjustment?

      charge.percentage? || (charge.prorated? && charge.graduated?)
    end

    def unit_adjustment?
      params[:units].present? && params[:unit_precise_amount].blank?
    end
  end
end
