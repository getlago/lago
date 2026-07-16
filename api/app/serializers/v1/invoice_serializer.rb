# frozen_string_literal: true

module V1
  class InvoiceSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        billing_entity_code: model.billing_entity.code,
        sequential_id: model.sequential_id,
        number: model.number,
        purchase_order_number: model.purchase_order_number,
        issuing_date: model.issuing_date&.iso8601,
        payment_due_date: model.payment_due_date&.iso8601,
        net_payment_term: model.net_payment_term,
        invoice_type: model.invoice_type,
        status: model.status,
        payment_status: model.payment_status,
        payment_dispute_lost_at: model.payment_dispute_lost_at,
        payment_overdue: model.payment_overdue,
        currency: model.currency,
        fees_amount_cents: model.fees_amount_cents,
        taxes_amount_cents: model.taxes_amount_cents,
        progressive_billing_credit_amount_cents: model.progressive_billing_credit_amount_cents,
        coupons_amount_cents: model.coupons_amount_cents,
        credit_notes_amount_cents: model.credit_notes_amount_cents,
        sub_total_excluding_taxes_amount_cents: model.sub_total_excluding_taxes_amount_cents,
        sub_total_including_taxes_amount_cents: model.sub_total_including_taxes_amount_cents,
        total_amount_cents: model.total_amount_cents,
        total_due_amount_cents: model.total_due_amount_cents,
        total_paid_amount_cents: model.total_paid_amount_cents,
        total_offsetted_credit_note_amount_cents: model.offset_amount_cents,
        prepaid_credit_amount_cents: model.prepaid_credit_amount_cents,
        prepaid_granted_credit_amount_cents: model.prepaid_granted_credit_amount_cents,
        prepaid_purchased_credit_amount_cents: model.prepaid_purchased_credit_amount_cents,
        file_url: model.file_url,
        xml_url: model.xml_url,
        version_number: model.version_number,
        self_billed: model.self_billed,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601,
        voided_at: model.voided_at&.iso8601
      }

      payload.merge!(customer) if include?(:customer)
      payload.merge!(subscriptions) if include?(:subscriptions)
      payload.merge!(billing_periods) if include?(:billing_periods)
      payload.merge!(fees) if include?(:fees)
      payload.merge!(credits) if include?(:credits)
      payload.merge!(metadata) if include?(:metadata)
      payload.merge!(applied_taxes) if include?(:applied_taxes)
      payload.merge!(error_details) if include?(:error_details)
      payload.merge!(applied_usage_thresholds) if model.progressive_billing?
      payload.merge!(applied_invoice_custom_sections) if include?(:applied_invoice_custom_sections)
      payload.merge!(preview_subscriptions) if include?(:preview_subscriptions)
      payload.merge!(preview_fees) if include?(:preview_fees)

      payload
    end

    private

    def customer
      {
        customer: ::V1::CustomerSerializer.new(
          model.customer,
          includes: include?(:integration_customers) ? [:integration_customers] : []
        ).serialize
      }
    end

    def subscriptions
      ::CollectionSerializer.new(
        model.sorted_invoice_subscriptions.includes(subscription: [:customer, :plan]).map(&:subscription),
        ::V1::SubscriptionSerializer,
        collection_name: "subscriptions",
        organization: model.organization
      ).serialize
    end

    def preview_subscriptions
      ::CollectionSerializer.new(
        model.subscriptions, ::V1::SubscriptionSerializer,
        collection_name: "subscriptions",
        organization: model.organization
      ).serialize
    end

    def fees
      ::CollectionSerializer.new(
        model.fees.includes(
          [
            :true_up_fee,
            :subscription,
            :customer,
            :charge,
            :billable_metric,
            :presentation_breakdowns,
            {charge_filter: {values: :billable_metric_filter}}
          ]
        ),
        ::V1::FeeSerializer,
        collection_name: "fees"
      ).serialize
    end

    def preview_fees
      ::CollectionSerializer.new(
        model.fees, ::V1::FeeSerializer, collection_name: "fees"
      ).serialize
    end

    def credits
      ::CollectionSerializer.new(model.credits, ::V1::CreditSerializer, collection_name: "credits").serialize
    end

    def metadata
      ::CollectionSerializer.new(
        model.metadata,
        ::V1::Invoices::MetadataSerializer,
        collection_name: "metadata"
      ).serialize
    end

    def applied_taxes
      ::CollectionSerializer.new(
        model.applied_taxes,
        ::V1::Invoices::AppliedTaxSerializer,
        collection_name: "applied_taxes"
      ).serialize
    end

    def error_details
      ::CollectionSerializer.new(
        model.error_details,
        ::V1::ErrorDetailSerializer,
        collection_name: "error_details"
      ).serialize
    end

    def applied_usage_thresholds
      ::CollectionSerializer.new(
        model.applied_usage_thresholds,
        ::V1::AppliedUsageThresholdSerializer,
        collection_name: "applied_usage_thresholds"
      ).serialize
    end

    def applied_invoice_custom_sections
      ::CollectionSerializer.new(
        model.applied_invoice_custom_sections,
        ::V1::Invoices::AppliedInvoiceCustomSectionSerializer,
        collection_name: "applied_invoice_custom_sections"
      ).serialize
    end

    def billing_periods
      ::CollectionSerializer.new(
        model.sorted_invoice_subscriptions,
        ::V1::Invoices::BillingPeriodSerializer,
        collection_name: "billing_periods"
      ).serialize
    end
  end
end
