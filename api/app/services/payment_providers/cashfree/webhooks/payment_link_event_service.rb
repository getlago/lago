# frozen_string_literal: true

module PaymentProviders
  module Cashfree
    module Webhooks
      class PaymentLinkEventService < BaseService
        LINK_STATUS_ACTIONS = %w[PAID].freeze

        PAYMENT_SERVICE_CLASS_MAP = {
          "Invoice" => Invoices::Payments::CashfreeService,
          "PaymentRequest" => PaymentRequests::Payments::CashfreeService
        }.freeze

        def call
          return result unless LINK_STATUS_ACTIONS.include?(link_status)
          return result if provider_payment_id.nil?

          payment_service_class.new.update_payment_status(
            organization_id: organization.id,
            status: link_status,
            amount_cents: link_amount_paid_cents,
            cashfree_payment: PaymentProviders::CashfreeProvider::CashfreePayment.new(
              id: provider_payment_id,
              status: link_status,
              metadata: event.dig("data", "link_notes").to_h.symbolize_keys || {}
            )
          ).raise_if_error!
        end

        private

        def payment_service_class
          PAYMENT_SERVICE_CLASS_MAP.fetch(payable_type || "Invoice") do
            raise NameError, "Invalid lago_payable_type: #{payable_type}"
          end
        end

        def link_status
          @link_status ||= event.dig("data", "link_status")
        end

        def provider_payment_id
          @provider_payment_id ||= event.dig("data", "link_notes", "lago_invoice_id") || event.dig("data", "link_notes", "lago_payable_id")
        end

        def payable_type
          @payable_type ||= event.dig("data", "link_notes", "lago_payable_type")
        end

        def link_amount_paid_cents
          raw = event.dig("data", "link_amount_paid")
          currency = event.dig("data", "link_currency")
          return nil if raw.nil? || currency.nil?

          Money.from_amount(raw.to_d, currency).cents
        end
      end
    end
  end
end
