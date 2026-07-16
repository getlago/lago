# frozen_string_literal: true

module Types
  module ActivityLogs
    class ResourceObject < Types::BaseUnion
      graphql_name "ActivityLogResourceObject"

      description "Activity log resource"

      possible_types Types::BillableMetrics::Object,
        Types::Plans::Object,
        Types::Customers::Object,
        Types::Invoices::Object,
        Types::CreditNotes::Object,
        Types::BillingEntities::Object,
        Types::Subscriptions::Object,
        Types::Wallets::Object,
        Types::Coupons::Object,
        Types::PaymentRequests::Object,
        Types::PaymentReceipts::Object,
        Types::Entitlement::FeatureObject

      def self.resolve_type(object, _context)
        case object.class.to_s
        when "BillableMetric"
          Types::BillableMetrics::Object
        when "Plan"
          Types::Plans::Object
        when "Customer"
          Types::Customers::Object
        when "Invoice"
          Types::Invoices::Object
        when "CreditNote"
          Types::CreditNotes::Object
        when "BillingEntity"
          Types::BillingEntities::Object
        when "Subscription"
          Types::Subscriptions::Object
        when "Wallet"
          Types::Wallets::Object
        when "Coupon"
          Types::Coupons::Object
        when "PaymentRequest"
          Types::PaymentRequests::Object
        when "PaymentReceipt"
          Types::PaymentReceipts::Object
        when "Entitlement::Feature"
          Types::Entitlement::FeatureObject
        else
          raise "Unexpected activity log resource type: #{object.inspect}"
        end
      end
    end
  end
end
