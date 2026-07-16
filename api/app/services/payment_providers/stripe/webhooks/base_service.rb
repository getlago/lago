# frozen_string_literal: true

module PaymentProviders
  module Stripe
    module Webhooks
      class BaseService < BaseService
        def initialize(organization_id:, event:)
          @organization = Organization.find(organization_id)
          @event = event

          super
        end

        private

        attr_reader :organization, :event

        PAYMENT_SERVICE_CLASS_MAP = {
          "Invoice" => Invoices::Payments::StripeService,
          "PaymentRequest" => PaymentRequests::Payments::StripeService
        }.freeze

        def metadata
          @metadata ||= event.data.object.metadata.to_h.symbolize_keys
        end

        def handle_missing_customer
          return result if stripe_customer_created_outside_lago?

          # NOTE: Lago customer either:
          #         - does not exist
          #         - exists but does not belong to the organization (Happens when the Stripe API key is shared between organizations)
          #         - exists but was updated to be linked to another stripe customer
          return result if metadata_does_not_match_lago_customer?

          result.not_found_failure!(resource: "stripe_customer")
        end

        def metadata_does_not_match_lago_customer?
          lago_customer = Customer.find_by(id: metadata[:lago_customer_id], organization_id: organization.id)

          lago_customer.nil? || linked_to_another_stripe_customer?(lago_customer)
        end

        def linked_to_another_stripe_customer?(lago_customer)
          lago_customer.stripe_customer.present?
        end

        def stripe_customer_created_outside_lago?
          metadata.nil? || !metadata.key?(:lago_customer_id)
        end

        # TODO: Move this to a proper factory
        def payment_service_klass
          payable_type = metadata[:lago_payable_type] || "Invoice"

          PAYMENT_SERVICE_CLASS_MAP.fetch(payable_type) do
            raise NameError, "Invalid lago_payable_type: #{payable_type}"
          end
        end

        def update_payment_status!(status)
          payment_service_klass.new.update_payment_status(
            organization_id: organization.id,
            status:,
            amount_cents: event.data.object.try(:amount),
            stripe_payment: PaymentProviders::StripeProvider::StripePayment.new(
              id: event.data.object.id,
              status: event.data.object.status,
              metadata:,
              error_code: event.data.object.to_hash.dig(:last_payment_error, :code)
            )
          ).raise_if_error!
        end
      end
    end
  end
end
