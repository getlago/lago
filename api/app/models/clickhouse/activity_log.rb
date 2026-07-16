# frozen_string_literal: true

module Clickhouse
  class ActivityLog < BaseRecord
    self.table_name = "activity_logs"
    self.primary_key = nil

    belongs_to :organization
    belongs_to :resource, polymorphic: true

    belongs_to :customer,
      -> { with_discarded },
      primary_key: :external_id,
      foreign_key: :external_customer_id,
      optional: true

    belongs_to :subscription,
      primary_key: :external_id,
      foreign_key: :external_subscription_id,
      optional: true

    belongs_to :user, optional: true
    belongs_to :api_key, optional: true

    RESOURCE_TYPES_WITH_DISCARDED = %w[BillableMetric Plan Customer BillingEntity Coupon].freeze

    RESOURCE_TYPES = {
      billable_metric: "BillableMetric",
      plan: "Plan",
      customer: "Customer",
      invoice: "Invoice",
      credit_note: "CreditNote",
      billing_entity: "BillingEntity",
      subscription: "Subscription",
      wallet: "Wallet",
      coupon: "Coupon",
      payment_receipt: "PaymentReceipt",
      payment_request: "PaymentRequest",
      feature: "Entitlement::Feature"
    }.freeze

    ACTIVITY_TYPES = {
      billable_metric_created: "billable_metric.created",
      billable_metric_updated: "billable_metric.updated",
      billable_metric_deleted: "billable_metric.deleted",
      plan_created: "plan.created",
      plan_updated: "plan.updated",
      plan_deleted: "plan.deleted",
      customer_created: "customer.created",
      customer_updated: "customer.updated",
      customer_deleted: "customer.deleted",
      invoice_drafted: "invoice.drafted",
      invoice_ready_to_finalize: "invoice.ready_to_finalize",
      invoice_failed: "invoice.failed",
      invoice_created: "invoice.created",
      invoice_one_off_created: "invoice.one_off_created",
      invoice_paid_credit_added: "invoice.paid_credit_added",
      invoice_generated: "invoice.generated",
      invoice_payment_status_updated: "invoice.payment_status_updated",
      invoice_payment_overdue: "invoice.payment_overdue",
      invoice_voided: "invoice.voided",
      invoice_regenerated: "invoice.regenerated",
      invoice_payment_failure: "invoice.payment_failure",
      payment_receipt_created: "payment_receipt.created",
      payment_receipt_generated: "payment_receipt.generated",
      credit_note_created: "credit_note.created",
      credit_note_generated: "credit_note.generated",
      credit_note_refund_failure: "credit_note.refund_failure",
      billing_entities_created: "billing_entities.created",
      billing_entities_updated: "billing_entities.updated",
      billing_entities_deleted: "billing_entities.deleted",
      subscription_canceled: "subscription.canceled",
      subscription_incomplete: "subscription.incomplete",
      subscription_started: "subscription.started",
      subscription_terminated: "subscription.terminated",
      subscription_updated: "subscription.updated",
      wallet_created: "wallet.created",
      wallet_updated: "wallet.updated",
      wallet_transaction_payment_failure: "wallet_transaction.payment_failure",
      wallet_transaction_created: "wallet_transaction.created",
      wallet_transaction_updated: "wallet_transaction.updated",
      payment_recorded: "payment.recorded",
      coupon_created: "coupon.created",
      coupon_updated: "coupon.updated",
      coupon_deleted: "coupon.deleted",
      applied_coupon_created: "applied_coupon.created",
      applied_coupon_deleted: "applied_coupon.deleted",
      payment_request_created: "payment_request.created",
      email_sent: "email.sent",
      feature_created: "feature.created",
      feature_deleted: "feature.deleted",
      feature_updated: "feature.updated"
    }

    before_save :ensure_activity_id

    # TODO: Remove this once we have soft deletion everywhere
    def resource
      return nil if resource_type.blank? || resource_id.blank?

      klass = resource_type.safe_constantize
      if RESOURCE_TYPES_WITH_DISCARDED.include?(resource_type)
        klass.with_discarded.find_by(organization_id: organization.id, id: resource_id)
      else
        klass.find_by(organization_id: organization.id, id: resource_id)
      end
    end

    private

    def ensure_activity_id
      self.activity_id = SecureRandom.uuid if activity_id.blank?
    end
  end
end

# == Schema Information
#
# Table name: activity_logs
# Database name: clickhouse
#
#  activity_object          :string
#  activity_object_changes  :string
#  activity_source          :Enum8('api' = 1, not null
#  activity_type            :string           not null
#  logged_at                :datetime         not null
#  resource_type            :string           not null
#  created_at               :datetime         not null
#  activity_id              :string           not null
#  api_key_id               :string
#  external_customer_id     :string
#  external_subscription_id :string
#  organization_id          :string           not null
#  resource_id              :string           not null
#  user_id                  :string
#
