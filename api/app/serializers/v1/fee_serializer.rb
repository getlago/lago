# frozen_string_literal: true

module V1
  class FeeSerializer < ModelSerializer
    def serialize
      subunit_to_unit = model.amount.currency.subunit_to_unit.to_d

      payload = {
        lago_id: model.id,
        lago_charge_id: model.charge_id,
        lago_charge_filter_id: model.charge_filter_id,
        lago_fixed_charge_id: model.fixed_charge_id,
        lago_invoice_id: model.invoice_id,
        lago_true_up_fee_id: model.true_up_fee&.id,
        lago_true_up_parent_fee_id: model.true_up_parent_fee_id,
        lago_original_fee_id: model.original_fee_id,
        lago_subscription_id: model.subscription_id,
        external_subscription_id: model.subscription&.external_id,
        lago_customer_id: model.customer&.id,
        external_customer_id: model.customer&.external_id,
        item: {
          type: model.fee_type,
          code: model.item_code,
          name: model.item_name,
          description: model.item_description,
          invoice_display_name: model.invoice_name,
          filters: model.charge_filter&.to_h,
          filter_invoice_display_name: model.charge_filter&.display_name,
          lago_item_id: model.item_id,
          item_type: model.item_type,
          grouped_by: model.grouped_by
        },
        pay_in_advance:,
        invoiceable:,
        amount_cents: model.amount_cents,
        amount_currency: model.amount_currency,
        precise_amount: model.precise_amount_cents.fdiv(subunit_to_unit),
        precise_total_amount: model.precise_total_amount_cents.fdiv(subunit_to_unit),
        taxes_amount_cents: model.taxes_amount_cents,
        taxes_precise_amount: model.taxes_precise_amount_cents.fdiv(subunit_to_unit),
        taxes_rate: model.taxes_rate,
        total_aggregated_units: model.total_aggregated_units,
        total_amount_cents: model.total_amount_cents,
        total_amount_currency: model.amount_currency,
        units: model.units,
        description: model.description,
        precise_unit_amount: model.precise_unit_amount,
        precise_coupons_amount_cents: model.precise_coupons_amount_cents,
        sub_total_excluding_taxes_amount_cents: model.sub_total_excluding_taxes_amount_cents.round,
        sub_total_excluding_taxes_precise_amount_cents: model.sub_total_excluding_taxes_precise_amount_cents,
        events_count: model.events_count,
        payment_status: model.payment_status,
        created_at: model.created_at&.iso8601,
        succeeded_at: model.succeeded_at&.iso8601,
        failed_at: model.failed_at&.iso8601,
        refunded_at: model.refunded_at&.iso8601,
        amount_details: model.amount_details,
        self_billed: model.invoice&.self_billed || false,
        pricing_unit_details:,
        presentation_breakdowns: model.presentation_breakdowns_displayed_in_invoice.map { |breakdown| PresentationBreakdownSerializer.new(breakdown).serialize }
      }

      payload.merge!(model.date_boundaries) if model.charge? || model.subscription? || model.add_on? || model.fixed_charge?
      payload.merge!(pay_in_advance_charge_attributes) if model.pay_in_advance? && model.charge?
      payload.merge!(applied_taxes) if include?(:applied_taxes)

      payload
    end

    private

    def pay_in_advance_charge_attributes
      return {} unless model.pay_in_advance?

      {event_transaction_id: model.pay_in_advance_event_transaction_id}
    end

    def applied_taxes
      ::CollectionSerializer.new(
        model.applied_taxes,
        ::V1::Fees::AppliedTaxSerializer,
        collection_name: "applied_taxes"
      ).serialize
    end

    def pay_in_advance
      if model.charge? || model.fixed_charge?
        model.pay_in_advance
      elsif model.subscription?
        model.subscription&.plan&.pay_in_advance
      else
        false
      end
    end

    def invoiceable
      model.charge? ? model.charge&.invoiceable : true
    end

    def pricing_unit_details
      return if model.pricing_unit_usage.nil?

      ::V1::PricingUnitUsageSerializer.new(model.pricing_unit_usage).serialize
    end
  end
end
