# frozen_string_literal: true

module Subscriptions
  class ProgressiveBilledAmount < BaseService
    Result = BaseResult[
      :progressive_billed_amount,
      :progressive_billing_invoice,
      :to_credit_amount,
      :total_billed_amount_cents,
      :invoice_subscriptions
    ]

    def initialize(subscription:, timestamp: Time.current, include_generating_invoices: false)
      @subscription = subscription
      @timestamp = timestamp
      @include_generating_invoices = include_generating_invoices

      super
    end

    def call
      result.progressive_billed_amount = 0
      result.total_billed_amount_cents = 0
      result.progressive_billing_invoice = nil
      result.to_credit_amount = 0

      # Note: we might be refreshing balance while applying credits on generating invoice.
      # in this case this invoice should be included
      invoices_scope = if include_generating_invoices
        Invoice.finalized.or(Invoice.failed).or(Invoice.generating)
      else
        Invoice.finalized.or(Invoice.failed)
      end
      invoice_subscriptions = InvoiceSubscription
        .where("charges_to_datetime > ?", timestamp)
        .where("charges_from_datetime <= ?", timestamp)
        .joins(:invoice)
        .merge(Invoice.progressive_billing)
        .merge(invoices_scope)
        .where(subscription: subscription)
        .order("invoices.issuing_date" => :desc, "invoices.created_at" => :desc)

      result.invoice_subscriptions = invoice_subscriptions
      return result if invoice_subscriptions.blank?

      # Note: included in scope generating invoice won't have values, so we have to iterate through the fees,
      # but progressively billed fees include previously progressively paid fees, so we need to get
      # sub_total_excluding_taxes_amount_cents and taxes_amount_cents from fees to get the exact billed amount
      total_billed_amount_cents = invoice_subscriptions.sum do |invoice_subscription|
        invoice_subscription.invoice.fees.sum(&:taxes_amount_cents) +
          invoice_subscription.invoice.fees.sum(&:sub_total_excluding_taxes_amount_cents)
      end
      result.total_billed_amount_cents = total_billed_amount_cents

      invoice_subscription = invoice_subscriptions.first
      invoice = invoice_subscription.invoice
      result.progressive_billing_invoice = invoice
      result.progressive_billed_amount = result.progressive_billing_invoice.fees_amount_cents

      result.to_credit_amount = invoice.fees_amount_cents
      result.to_credit_amount -= invoice.coupons_amount_cents
      result.to_credit_amount -= invoice.progressive_billing_credits.active.sum(:amount_cents)
      result.to_credit_amount -= invoice.credit_notes.where(credit_status: ["available", "consumed"]).sum(:credit_amount_cents)

      # if for some reason this goes below zero, it should be zero.
      result.to_credit_amount = 0 if result.to_credit_amount.negative?

      result
    end

    private

    attr_reader :subscription, :timestamp, :include_generating_invoices
  end
end
