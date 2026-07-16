# frozen_string_literal: true

module Types
  module Subscriptions
    class Object < Types::BaseObject
      graphql_name "Subscription"

      field :billing_entity_id, ID, null: true
      field :customer, Types::Customers::Object, null: false
      field :external_id, String, null: false
      field :id, ID, null: false
      field :plan, Types::Plans::Object, null: false

      field :name, String, null: true
      field :period_end_date, GraphQL::Types::ISO8601Date
      field :status, Types::Subscriptions::StatusTypeEnum

      field :billing_time, Types::Subscriptions::BillingTimeEnum
      field :canceled_at, GraphQL::Types::ISO8601DateTime
      field :ending_at, GraphQL::Types::ISO8601DateTime
      field :on_termination_credit_note, Types::Subscriptions::OnTerminationCreditNoteEnum
      field :on_termination_invoice, Types::Subscriptions::OnTerminationInvoiceEnum, null: false
      field :started_at, GraphQL::Types::ISO8601DateTime
      field :subscription_at, GraphQL::Types::ISO8601DateTime
      field :terminated_at, GraphQL::Types::ISO8601DateTime

      field :current_billing_period_ending_at, GraphQL::Types::ISO8601DateTime
      field :current_billing_period_started_at, GraphQL::Types::ISO8601DateTime

      field :selected_invoice_custom_sections, [Types::InvoiceCustomSections::Object], null: true
      field :skip_invoice_custom_sections, Boolean

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :downgrade_plan_date, GraphQL::Types::ISO8601Date
      field :next_name, String, null: true
      field :next_plan, Types::Plans::Object
      field :next_subscription, Types::Subscriptions::Object
      field :next_subscription_at, GraphQL::Types::ISO8601DateTime
      field :next_subscription_type, Types::Subscriptions::NextSubscriptionTypeEnum
      field :previous_plan, Types::Plans::Object
      field :previous_subscription, Types::Subscriptions::Object

      field :activity_logs, [Types::ActivityLogs::Object], null: true
      field :charges, [Types::Charges::Object], null: true
      field :fees, [Types::Fees::Object], null: true
      field :fixed_charges, [Types::FixedCharges::Object], null: true

      field :lifetime_usage, Types::Subscriptions::LifetimeUsageObject, null: true

      field :usage_thresholds, [Types::UsageThresholds::Object], null: false

      field :consolidate_invoice, Boolean, null: false
      field :payment_method, Types::PaymentMethods::Object
      field :payment_method_type, Types::PaymentMethods::MethodTypeEnum
      field :progressive_billing_disabled, Boolean

      field :activated_at, GraphQL::Types::ISO8601DateTime, null: true
      field :activation_rules, [Types::Subscriptions::ActivationRuleType], null: false
      field :cancellation_reason, Types::Subscriptions::CancellationReasonEnum, null: true

      def next_plan
        object.next_subscription&.plan
      end

      def previous_plan
        object.previous_subscription&.plan
      end

      def next_name
        object.next_subscription&.name
      end

      def next_subscription_type
        if object.upgraded?
          "upgrade"
        elsif object.downgraded?
          "downgrade"
        end
      end

      def next_subscription_at
        object.next_subscription&.started_at || object.next_subscription&.subscription_at
      end

      def period_end_date
        ::Subscriptions::DatesService.new_instance(object, object.billing_reference_time)
          .next_end_of_period
      end

      def lifetime_usage
        return nil unless object.has_progressive_billing? || object.organization.lifetime_usage_enabled?

        object.lifetime_usage
      end

      def current_billing_period_started_at
        dates_service.charges_from_datetime
      end

      def current_billing_period_ending_at
        dates_service.charges_to_datetime
      end

      def charges
        object.plan.charges
          .includes(:billable_metric, :taxes, :applied_pricing_unit, filters: :billable_metric_filters)
          .order(created_at: :asc)
      end

      def fixed_charges
        fcs = object.plan.fixed_charges
          .includes(:add_on, :taxes)
          .order(created_at: :asc)

        effective_units_by_id = ::Subscription::FixedChargeUnitsOverride.units_map_for(
          subscription: object,
          fixed_charges: fcs
        )

        fcs.map do |fc|
          ::Subscription::FixedChargePresenter.new(fc, object, effective_units: effective_units_by_id[fc.id])
        end
      end

      def dates_service
        @dates_service ||= ::Subscriptions::DatesService.new_instance(object, object.billing_reference_time, current_usage: true)
      end
    end
  end
end
