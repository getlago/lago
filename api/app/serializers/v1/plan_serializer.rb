# frozen_string_literal: true

module V1
  class PlanSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        name: model.name,
        invoice_display_name: model.invoice_display_name,
        created_at: model.created_at.iso8601,
        code: model.code,
        interval: model.interval,
        description: model.description,
        amount_cents: model.amount_cents,
        amount_currency: model.amount_currency,
        trial_period: model.trial_period,
        pay_in_advance: model.pay_in_advance,
        bill_charges_monthly: model.bill_charges_monthly,
        bill_fixed_charges_monthly: model.bill_fixed_charges_monthly,
        customers_count: 0,
        active_subscriptions_count: 0,
        draft_invoices_count: 0,
        parent_id: model.parent_id, # TODO: rename to lago_parent_id
        pending_deletion: model.pending_deletion
      }

      payload.merge!(charges) if include?(:charges)
      payload.merge!(fixed_charges) if include?(:fixed_charges)
      payload.merge!(entitlements) if include?(:entitlements)
      payload.merge!(usage_thresholds) if include?(:usage_thresholds)
      payload.merge!(applicable_usage_thresholds) if include?(:applicable_usage_thresholds)
      payload.merge!(taxes) if include?(:taxes)
      payload.merge!(minimum_commitment) if include?(:minimum_commitment) && model.minimum_commitment
      payload.merge!(metadata) if model.metadata.present?

      payload
    end

    private

    def charges
      ::CollectionSerializer.new(
        model.charges.includes(:applied_pricing_unit, :billable_metric, :taxes, filters: [:charge, {values: :billable_metric_filter}]),
        ::V1::ChargeSerializer,
        collection_name: "charges",
        includes: include?(:taxes) ? %i[taxes] : []
      ).serialize
    end

    def fixed_charges
      ::CollectionSerializer.new(
        model.fixed_charges,
        ::V1::FixedChargeSerializer,
        collection_name: "fixed_charges",
        includes: include?(:taxes) ? %i[taxes] : []
      ).serialize
    end

    def entitlements
      ::CollectionSerializer.new(
        model.entitlements.includes(:feature, values: :privilege),
        ::V1::Entitlement::PlanEntitlementSerializer,
        collection_name: "entitlements"
      ).serialize
    end

    def usage_thresholds
      ::CollectionSerializer.new(
        model.usage_thresholds,
        ::V1::UsageThresholdSerializer,
        collection_name: "usage_thresholds"
      ).serialize
    end

    def applicable_usage_thresholds
      ::CollectionSerializer.new(
        model.applicable_usage_thresholds,
        ::V1::ApplicableUsageThresholdSerializer,
        collection_name: "applicable_usage_thresholds"
      ).serialize
    end

    def minimum_commitment
      {
        minimum_commitment: V1::CommitmentSerializer.new(
          model.minimum_commitment,
          includes: include?(:taxes) ? %i[taxes] : []
        ).serialize.except(:commitment_type)
      }
    end

    def taxes
      ::CollectionSerializer.new(
        model.taxes,
        ::V1::TaxSerializer,
        collection_name: "taxes"
      ).serialize
    end

    def metadata
      {
        metadata: ::V1::MetadataSerializer.new(model.metadata).serialize
      }
    end
  end
end
