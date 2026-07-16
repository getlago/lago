# frozen_string_literal: true

module PaymentProviders
  class UpdatePaymentReferenceService < BaseService
    Result = BaseResult[:payment]

    def initialize(payment:)
      @payment = payment
      super
    end

    def call
      result.payment = payment

      return result if payment.payment_provider.blank?
      return result if payment.provider_payment_id.blank?

      case payment.payment_provider.type
      when "PaymentProviders::StripeProvider"
        delegate_to(PaymentProviders::Stripe::Payments::UpdateReferenceService)
      else
        # Stripe is the only provider whose payment reference can be corrected
        # after the gated invoice is finalized. The rest are intentionally
        # skipped:
        # - Adyen sets a placeholder merchantReference at creation, but it is
        #   immutable post-authorization and the SDK exposes no surface to
        #   update a captured payment's reference or metadata.
        # - GoCardless never carries the invoice number at creation (no
        #   reference field, not in metadata), so there is no placeholder to
        #   correct.
        # - Cashfree, Flutterwave, and Moneyhash expose no metadata-update API.
        # Reconciliation on these providers relies on the lago payment/invoice
        # id; the gap is documented and accepted.
        Rails.logger.info(
          "PaymentProviders::UpdatePaymentReferenceService: no PSP reference update " \
          "for #{payment.payment_provider.type} (payment #{payment.id}); skipping"
        )
      end

      result
    end

    private

    attr_reader :payment

    def delegate_to(service)
      service.call!(payment:)
    end
  end
end
