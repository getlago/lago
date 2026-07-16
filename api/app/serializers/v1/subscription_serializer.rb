# frozen_string_literal: true

module V1
  class SubscriptionSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        external_id: model.external_id,
        lago_customer_id: model.customer_id,
        external_customer_id: model.customer.external_id,
        name: model.name,
        plan_code: model.plan.code,
        plan_amount_cents: model.plan.amount_cents,
        plan_amount_currency: model.plan.amount_currency,
        status: model.status,
        billing_time: model.billing_time,
        subscription_at: model.subscription_at&.iso8601,
        started_at: model.started_at&.iso8601(3),
        trial_ended_at: model.trial_ended_at&.iso8601,
        ending_at: model.ending_at&.iso8601,
        terminated_at: model.terminated_at&.iso8601,
        canceled_at: model.canceled_at&.iso8601,
        created_at: model.created_at.iso8601,
        previous_plan_code: model.previous_subscription&.plan&.code,
        next_plan_code: model.next_subscription&.plan&.code,
        downgrade_plan_date: model.downgrade_plan_date&.iso8601,
        current_billing_period_started_at: dates_service.charges_from_datetime&.iso8601,
        current_billing_period_ending_at: dates_service.charges_to_datetime&.iso8601,
        on_termination_credit_note: model.on_termination_credit_note,
        on_termination_invoice: model.on_termination_invoice,
        progressive_billing_disabled: model.progressive_billing_disabled,
        consolidate_invoice: model.consolidate_invoice,
        cancellation_reason: model.cancellation_reason,
        activated_at: model.activated_at&.iso8601
      }

      payload = payload.merge(customer:) if include?(:customer)
      payload = payload.merge(entitlements) if include?(:entitlements)
      payload = payload.merge(payment_method)
      payload = payload.merge(plan:) if include?(:plan)
      payload = payload.merge(usage_threshold:) if include?(:usage_threshold)
      payload = payload.merge(applicable_usage_thresholds) if include?(:applicable_usage_thresholds)
      payload = payload.merge(applied_invoice_custom_sections) if include?(:applied_invoice_custom_sections)
      payload.merge(activation_rules)
    end

    private

    def organization
      options[:organization] || model.organization
    end

    def customer
      ::V1::CustomerSerializer.new(model.customer).serialize
    end

    def entitlements
      ::CollectionSerializer.new(
        ::Entitlement::SubscriptionEntitlement.for_subscription(model),
        ::V1::Entitlement::SubscriptionEntitlementSerializer,
        collection_name: "entitlements"
      ).serialize
    end

    def plan
      ::V1::PlanSerializer.new(
        model.plan,
        includes: included_relations(
          :plan,
          default: %i[charges usage_thresholds applicable_usage_thresholds taxes minimum_commitment]
        )
      ).serialize
    end

    def activation_rules
      ::CollectionSerializer.new(
        model.activation_rules,
        ::V1::Subscriptions::ActivationRuleSerializer,
        collection_name: "activation_rules"
      ).serialize
    end

    # NOTE: This attribute is only used when sending the `subscription.usage_threshold_reached` webhook
    #      Ideally, this shouldn't even be part of the `subscription` object
    def usage_threshold
      ::V1::UsageThresholdSerializer.new(options[:usage_threshold]).serialize
    end

    def dates_service
      @dates_service ||= ::Subscriptions::DatesService.new_instance(model, model.billing_reference_time, current_usage: true)
    end

    def applicable_usage_thresholds
      ::CollectionSerializer.new(
        model.applicable_usage_thresholds,
        ::V1::ApplicableUsageThresholdSerializer,
        collection_name: "applicable_usage_thresholds"
      ).serialize
    end

    def applied_invoice_custom_sections
      ::CollectionSerializer.new(
        model.applied_invoice_custom_sections,
        ::V1::AppliedInvoiceCustomSectionSerializer,
        collection_name: "applied_invoice_custom_sections"
      ).serialize
    end

    def payment_method
      {
        payment_method: {
          payment_method_id: model.payment_method_id,
          payment_method_type: model.payment_method_type
        }
      }
    end
  end
end
