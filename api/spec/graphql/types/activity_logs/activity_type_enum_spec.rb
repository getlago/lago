# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ActivityLogs::ActivityTypeEnum do
  it "enumerates the correct values" do
    expect(described_class.values.keys).to match_array(
      %w[
        billable_metric_created
        billable_metric_updated
        billable_metric_deleted
        plan_created
        plan_updated
        plan_deleted
        customer_created
        customer_updated
        customer_deleted
        invoice_drafted
        invoice_ready_to_finalize
        invoice_failed
        invoice_one_off_created
        invoice_created
        invoice_paid_credit_added
        invoice_generated
        invoice_payment_status_updated
        invoice_payment_overdue
        invoice_voided
        invoice_regenerated
        invoice_payment_failure
        payment_receipt_created
        payment_receipt_generated
        credit_note_created
        credit_note_generated
        credit_note_refund_failure
        billing_entities_created
        billing_entities_updated
        billing_entities_deleted
        subscription_canceled
        subscription_incomplete
        subscription_started
        subscription_terminated
        subscription_updated
        wallet_created
        wallet_updated
        wallet_transaction_payment_failure
        wallet_transaction_created
        wallet_transaction_updated
        payment_recorded
        coupon_created
        coupon_updated
        coupon_deleted
        applied_coupon_created
        applied_coupon_deleted
        payment_request_created
        feature_created
        feature_deleted
        feature_updated
        email_sent
      ]
    )
  end
end
