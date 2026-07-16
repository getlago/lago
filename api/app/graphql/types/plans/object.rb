# frozen_string_literal: true

module Types
  module Plans
    class Object < Types::BaseObject
      graphql_name "Plan"

      field :id, ID, null: false
      field :organization, Types::Organizations::OrganizationType

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :amount_currency, Types::CurrencyEnum, null: false
      field :bill_charges_monthly, Boolean
      field :bill_fixed_charges_monthly, Boolean
      field :code, String, null: false
      field :description, String
      field :interval, Types::Plans::IntervalEnum, null: false
      field :invoice_display_name, String
      field :minimum_commitment, Types::Commitments::Object, null: true
      field :name, String, null: false
      field :parent, Types::Plans::Object, null: true
      field :pay_in_advance, Boolean, null: false
      field :trial_period, Float

      field :applicable_usage_thresholds, [Types::UsageThresholds::Object]
      field :usage_thresholds, [Types::UsageThresholds::Object]

      field :entitlements, [Types::Entitlement::PlanEntitlementObject]

      field :activity_logs, [Types::ActivityLogs::Object], null: true
      field :charges, [Types::Charges::Object]
      field :fixed_charges, [Types::FixedCharges::Object]
      field :taxes, [Types::Taxes::Object]

      field :has_active_subscriptions, Boolean, null: false
      field :has_charges, Boolean, null: false
      field :has_customers, Boolean, null: false
      field :has_draft_invoices, Boolean, null: false
      field :has_fixed_charges, Boolean, null: false
      field :has_overridden_plans, Boolean
      field :has_subscriptions, Boolean, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :deleted_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :active_subscriptions_count, Integer, null: false
      field :charges_count, Integer, null: false, description: "Number of charges attached to a plan"
      field :customers_count, Integer, null: false, description: "Number of customers attached to a plan"
      field :draft_invoices_count, Integer, null: false
      field :fixed_charges_count, Integer, null: false, description: "Number of fixed charges attached to a plan"
      field :is_overridden, Boolean, null: false
      field :subscriptions_count, Integer, null: false

      field :metadata, [Types::Metadata::Object], null: true

      def entitlements
        object.entitlements.order(:created_at)
      end

      def applicable_usage_thresholds
        object.applicable_usage_thresholds.order(amount_cents: :asc)
      end

      def usage_thresholds
        object.usage_thresholds.order(amount_cents: :asc)
      end

      def charges
        object.charges.includes(filters: {values: :billable_metric_filter}).order(created_at: :asc)
      end

      def fixed_charges
        object.fixed_charges.order(created_at: :asc)
      end

      def charges_count
        object.charges.count
      end

      def fixed_charges_count
        object.fixed_charges.count
      end

      def subscriptions_count
        count = object.subscriptions.count
        return count unless object.children

        count + object.children.joins(:subscriptions).select("subscriptions.id").distinct.count
      end

      def is_overridden
        object.parent_id.present?
      end

      def has_active_subscriptions
        object.subscriptions.active.exists? || has_active_subscriptions_on_children
      end

      def has_active_subscriptions_on_children
        object.children.joins(:subscriptions).merge(Subscription.active).exists?
      end

      # NOTE: should this one include children charges?
      def has_charges
        object.charges.exists?
      end

      def has_fixed_charges
        object.fixed_charges.exists?
      end

      # NOTE: if it has active subscriptions, it has customers
      def has_customers
        has_active_subscriptions
      end

      def has_draft_invoices
        object.invoices.draft.exists? || has_draft_invoices_on_children
      end

      def has_draft_invoices_on_children
        object.children.joins(:invoices).merge(Invoice.draft).exists?
      end

      def has_overridden_plans
        object.children.exists?
      end

      def has_subscriptions
        object.subscriptions.exists? || has_subscriptions_on_children
      end

      def has_subscriptions_on_children
        object.children.joins(:subscriptions).exists?
      end

      def metadata
        object.metadata&.value
      end
    end
  end
end
