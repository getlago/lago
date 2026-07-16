# frozen_string_literal: true

module PaymentProviders
  module Flutterwave
    module Webhooks
      class ChargeCompletedService < BaseService
        SUCCESS_STATUSES = %w[successful].freeze

        PAYMENT_SERVICE_CLASS_MAP = {
          "Invoice" => Invoices::Payments::FlutterwaveService,
          "PaymentRequest" => PaymentRequests::Payments::FlutterwaveService
        }.freeze

        def initialize(organization_id:, event_json:)
          @organization_id = organization_id
          @event_json = event_json
          super
        end

        def call
          return result unless SUCCESS_STATUSES.include?(transaction_status)
          return result if provider_payment_id.nil?

          # Validate payable_type first to raise NameError for invalid types
          payment_service_class

          verified_transaction = verify_transaction
          return result unless verified_transaction

          payable = find_payable
          return result unless payable

          payment_service_class.new(payable:).update_payment_status(
            organization_id:,
            status: verified_transaction[:status],
            amount_cents: verified_amount_cents(verified_transaction),
            flutterwave_payment: PaymentProviders::FlutterwaveProvider::FlutterwavePayment.new(
              id: provider_payment_id,
              status: verified_transaction[:status],
              metadata: build_metadata(verified_transaction)
            )
          ).raise_if_error!

          result
        end

        private

        attr_reader :organization_id, :event_json

        def event
          @event ||= JSON.parse(event_json)
        end

        def transaction_data
          @transaction_data ||= event["data"]
        end

        def transaction_status
          @transaction_status ||= transaction_data["status"]
        end

        def provider_payment_id
          @provider_payment_id ||= transaction_data.dig("meta", "lago_invoice_id") ||
            transaction_data.dig("meta", "lago_payable_id") ||
            transaction_data["tx_ref"]
        end

        def payable_type
          @payable_type ||= transaction_data.dig("meta", "lago_payable_type") || "Invoice"
        end

        def payment_service_class
          PAYMENT_SERVICE_CLASS_MAP.fetch(payable_type || "Invoice") do
            raise NameError, "Invalid lago_payable_type: #{payable_type}"
          end
        end

        def find_payable
          case payable_type
          when "Invoice"
            Invoice.find_by(id: provider_payment_id)
          when "PaymentRequest"
            PaymentRequest.find_by(id: provider_payment_id)
          end
        end

        def verify_transaction
          Organization.find(organization_id)
          payment_provider_result = PaymentProviders::FindService.call(
            organization_id:,
            payment_provider_type: "flutterwave"
          )

          return nil unless payment_provider_result.success?

          payment_provider = payment_provider_result.payment_provider

          begin
            verification_url = "#{payment_provider.api_url}/transactions/#{transaction_data["id"]}/verify"
            client = LagoHttpClient::Client.new(verification_url)

            response = client.get(
              headers: headers(payment_provider)
            )

            if response["status"] == "success" && response["data"]["status"] == "successful"
              {
                id: response["data"]["id"],
                status: response["data"]["status"],
                amount: response["data"]["amount"],
                currency: response["data"]["currency"],
                customer: response["data"]["customer"],
                reference: response["data"]["tx_ref"]
              }
            else
              Rails.logger.warn("Flutterwave transaction verification failed: #{response}")
              nil
            end
          rescue LagoHttpClient::HttpError => e
            Rails.logger.error("Error verifying Flutterwave transaction: #{e.message}")
            nil
          end
        end

        def build_metadata(verified_transaction)
          {
            lago_invoice_id: provider_payment_id,
            lago_payable_type: payable_type,
            flutterwave_transaction_id: verified_transaction[:id],
            flw_ref: verified_transaction[:reference],
            reference: verified_transaction[:reference],
            amount: verified_transaction[:amount],
            currency: verified_transaction[:currency],
            payment_type: "one-time"
          }
        end

        def verified_amount_cents(verified_transaction)
          amount = verified_transaction[:amount]
          currency = verified_transaction[:currency]
          return nil if amount.nil? || currency.nil?

          Money.from_amount(amount.to_d, currency).cents
        end

        def headers(payment_provider)
          {
            "Authorization" => "Bearer #{payment_provider.secret_key}",
            "Content-Type" => "application/json",
            "Accept" => "application/json"
          }
        end
      end
    end
  end
end
