# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService do
  subject(:charge_completed_service) { described_class.new(organization_id: organization.id, event_json:) }

  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, organization:) }
  let(:payment_request) { create(:payment_request, organization:) }
  let(:flutterwave_provider) { create(:flutterwave_provider, organization:) }
  let(:event_json) { payload.to_json }

  let(:payload) do
    {
      event: "charge.completed",
      data: {
        id: 285959875,
        tx_ref: "lago_invoice_12345",
        flw_ref: "LAGO/FLW270177170",
        device_fingerprint: "a42937f4a73ce8bb8b8df14e63a2df31",
        amount: 10000,
        currency: "NGN",
        charged_amount: 10000,
        app_fee: 140,
        merchant_fee: 0,
        processor_response: "Approved by Financial Institution",
        auth_model: "PIN",
        ip: "197.210.64.96",
        narration: "CARD Transaction",
        status: "successful",
        payment_type: "card",
        created_at: "2020-07-06T19:17:04.000Z",
        account_id: 17321,
        customer: {
          id: 215604089,
          name: "John Doe",
          phone_number: nil,
          email: "customer@example.com",
          created_at: "2020-07-06T19:17:04.000Z"
        },
        card: {
          first_6digits: "123456",
          last_4digits: "7889",
          issuer: "VERVE FIRST CITY MONUMENT BANK PLC",
          country: "NG",
          type: "VERVE", expiry: "02/23"
        },
        meta: {
          lago_invoice_id: invoice.id,
          lago_payable_type: "Invoice"
        }
      }
    }
  end

  let(:verification_response) do
    {
      "status" => "success",
      "data" => {
        "id" => 285959875,
        "tx_ref" => "lago_invoice_12345",
        "flw_ref" => "LAGO/FLW270177170",
        "amount" => 10000,
        "currency" => "NGN",
        "charged_amount" => 10000,
        "status" => "successful",
        "payment_type" => "card",
        "customer" => {
          "id" => 215604089,
          "name" => "John Doe",
          "email" => "customer@example.com"
        },
        "card" => {
          "first_6digits" => "123456",
          "last_4digits" => "7889",
          "issuer" => "VERVE FIRST CITY MONUMENT BANK PLC",
          "country" => "NG",
          "type" => "VERVE"
        }
      }
    }
  end

  before do
    allow(PaymentProviders::FindService)
      .to receive(:call)
      .with(organization_id: organization.id, payment_provider_type: "flutterwave")
      .and_return(double(success?: true, payment_provider: flutterwave_provider)) # rubocop:disable RSpec/VerifiedDoubles
  end

  describe "#call" do
    context "when transaction status is successful" do
      let(:http_client) { instance_double(LagoHttpClient::Client) }
      let(:payment_service) { instance_double(Invoices::Payments::FlutterwaveService) }

      before do
        invoice
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_return(verification_response)
        allow(Invoices::Payments::FlutterwaveService).to receive(:new).and_return(payment_service)
        allow(payment_service).to receive(:update_payment_status).and_return(instance_double("BaseService::Result", raise_if_error!: nil))
      end

      it "verifies the transaction and updates payment status" do
        result = charge_completed_service.call

        expect(http_client).to have_received(:get).with(
          headers: {
            "Authorization" => "Bearer #{flutterwave_provider.secret_key}",
            "Content-Type" => "application/json",
            "Accept" => "application/json"
          }
        )
        expect(payment_service).to have_received(:update_payment_status)
        expect(result).to be_success
      end

      it "builds correct metadata" do
        charge_completed_service.call

        expect(payment_service).to have_received(:update_payment_status) do |args|
          metadata = args[:flutterwave_payment].metadata
          expect(metadata[:lago_invoice_id]).to eq(invoice.id)
          expect(metadata[:lago_payable_type]).to eq("Invoice")
          expect(metadata[:flutterwave_transaction_id]).to eq(285959875)
          expect(metadata[:amount]).to eq(10000)
          expect(metadata[:currency]).to eq("NGN")
          expect(metadata[:flw_ref]).to eq("lago_invoice_12345")
        end
      end

      it "passes amount_cents converted from major units as a dedicated kwarg" do
        charge_completed_service.call

        expect(payment_service).to have_received(:update_payment_status).with(
          hash_including(amount_cents: 1_000_000)
        )
      end
    end

    context "when transaction status is not successful" do
      let(:payload) do
        {
          event: "charge.completed",
          data: {
            id: 408136545,
            tx_ref: "lago_invoice_12345",
            flw_ref: "LAGO/SM31570678271",
            device_fingerprint: "7852b6c97d67edce50a5f1e540719e39",
            amount: 100000,
            currency: "NGN",
            charged_amount: 100000,
            app_fee: 1400,
            merchant_fee: 0,
            processor_response: "invalid token supplied",
            auth_model: "PIN",
            ip: "72.140.222.142",
            narration: "CARD Transaction",
            status: "failed",
            payment_type: "card",
            created_at: "2021-04-16T14:52:37.000Z",
            account_id: 82913,
            customer: {
              id: 255128611,
              name: "Test User",
              phone_number: nil,
              email: "test@example.com",
              created_at: "2021-04-16T14:52:37.000Z"
            },
            card: {
              first_6digits: "536613",
              last_4digits: "8816",
              issuer: "MASTERCARD ACCESS BANK PLC CREDIT",
              country: "NG",
              type: "MASTERCARD",
              expiry: "12/21"
            },
            meta: {
              lago_invoice_id: "12345",
              lago_payable_type: "Invoice"
            }
          },
          "event.type": "CARD_TRANSACTION"
        }
      end

      before do
        allow(LagoHttpClient::Client).to receive(:new)
      end

      it "does not process the transaction" do
        result = charge_completed_service.call

        expect(LagoHttpClient::Client).not_to have_received(:new)
        expect(result).to be_success
      end
    end

    context "when provider payment id is nil" do
      let(:payload) do
        {
          event: "charge.completed",
          data: {
            id: 285959875,
            flw_ref: "LAGO/FLW270177170",
            amount: 10000,
            currency: "NGN",
            status: "successful",
            payment_type: "card",
            customer: {
              id: 215604089,
              name: "John Doe",
              email: "customer@example.com"
            }
            # tx_ref is missing, which should cause the service to skip processing
          }
        }
      end

      before do
        allow(LagoHttpClient::Client).to receive(:new)
      end

      it "does not process the transaction" do
        result = charge_completed_service.call

        expect(LagoHttpClient::Client).not_to have_received(:new)
        expect(result).to be_success
      end
    end

    context "when transaction verification fails" do
      let(:http_client) { instance_double(LagoHttpClient::Client) }
      let(:failed_response) do
        {
          "status" => "error",
          "message" => "Transaction not found"
        }
      end

      before do
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_return(failed_response)
        allow(Invoices::Payments::FlutterwaveService).to receive(:new)
      end

      it "does not update payment status" do
        result = charge_completed_service.call

        expect(Invoices::Payments::FlutterwaveService).not_to have_received(:new)
        expect(result).to be_success
      end
    end

    context "when payment provider is not found" do
      before do
        allow(PaymentProviders::FindService)
          .to receive(:call)
          .and_return(double(success?: false)) # rubocop:disable RSpec/VerifiedDoubles
        allow(LagoHttpClient::Client).to receive(:new)
      end

      it "does not process the transaction" do
        result = charge_completed_service.call

        expect(LagoHttpClient::Client).not_to have_received(:new)
        expect(result).to be_success
      end
    end

    context "when HTTP error occurs during verification" do
      let(:http_client) { instance_double(LagoHttpClient::Client) }

      before do
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_raise(LagoHttpClient::HttpError.new(500, "Connection failed", "https://api.flutterwave.com"))
        allow(Rails.logger).to receive(:error)
        allow(Invoices::Payments::FlutterwaveService).to receive(:new)
      end

      it "logs the error and does not update payment status" do
        result = charge_completed_service.call

        expect(Rails.logger).to have_received(:error).with("Error verifying Flutterwave transaction: HTTP 500 - URI: https://api.flutterwave.com.\nError: Connection failed\nResponse headers: {}")
        expect(Invoices::Payments::FlutterwaveService).not_to have_received(:new)
        expect(result).to be_success
      end
    end

    context "when payable type is PaymentRequest" do
      let(:payload) do
        {
          event: "charge.completed",
          data: {
            id: 285959875,
            tx_ref: "lago_payment_request_12345",
            flw_ref: "LAGO/FLW270177170",
            device_fingerprint: "a42937f4a73ce8bb8b8df14e63a2df31",
            amount: 50000,
            currency: "NGN",
            charged_amount: 50000,
            app_fee: 700,
            merchant_fee: 0,
            processor_response: "Approved by Financial Institution",
            auth_model: "PIN",
            ip: "197.210.64.96",
            narration: "CARD Transaction",
            status: "successful",
            payment_type: "card",
            created_at: "2020-07-06T19:17:04.000Z",
            account_id: 17321,
            customer: {
              id: 215604089,
              name: "John Doe",
              phone_number: nil,
              email: "customer@example.com",
              created_at: "2020-07-06T19:17:04.000Z"
            },
            card: {
              first_6digits: "123456",
              last_4digits: "7889",
              issuer: "VERVE FIRST CITY MONUMENT BANK PLC",
              country: "NG",
              type: "VERVE",
              expiry: "02/23"
            }, meta: {
              lago_payable_id: payment_request.id,
              lago_payable_type: "PaymentRequest"
            }
          }
        }
      end

      let(:http_client) { instance_double(LagoHttpClient::Client) }
      let(:payment_service) { instance_double(PaymentRequests::Payments::FlutterwaveService) }

      before do
        payment_request
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_return(verification_response)
        allow(PaymentRequests::Payments::FlutterwaveService).to receive(:new).and_return(payment_service)
        allow(payment_service).to receive(:update_payment_status).and_return(instance_double("BaseService::Result", raise_if_error!: nil))
      end

      it "uses the PaymentRequest service" do
        charge_completed_service.call

        expect(PaymentRequests::Payments::FlutterwaveService).to have_received(:new).with(payable: payment_request)
        expect(payment_service).to have_received(:update_payment_status)
      end
    end

    context "when payable type is invalid" do
      let(:payload) do
        {
          event: "charge.completed",
          data: {
            id: 285959875,
            tx_ref: "lago_invoice_12345",
            flw_ref: "LAGO/FLW270177170",
            amount: 10000,
            currency: "NGN",
            charged_amount: 10000,
            status: "successful",
            payment_type: "card",
            customer: {
              id: 215604089,
              name: "John Doe",
              email: "customer@example.com"
            }, meta: {
              lago_invoice_id: invoice.id,
              lago_payable_type: "InvalidType"
            }
          }
        }
      end

      let(:http_client) { instance_double(LagoHttpClient::Client) }

      before do
        invoice # Create the invoice so find_payable doesn't fail first
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_return(verification_response)
      end

      it "raises a NameError" do
        expect { charge_completed_service.call }.to raise_error(NameError, "Invalid lago_payable_type: InvalidType")
      end
    end

    context "when transaction has different currency precision" do
      let(:payload) do
        {
          event: "charge.completed",
          data: {
            id: 285959875,
            tx_ref: "lago_invoice_12345",
            flw_ref: "LAGO/FLW270177170",
            amount: 100.50,
            currency: "USD",
            charged_amount: 100.50,
            app_fee: 1.40,
            status: "successful",
            payment_type: "card",
            customer: {
              id: 215604089,
              name: "John Doe",
              email: "customer@example.com"
            },
            meta: {
              lago_invoice_id: invoice.id,
              lago_payable_type: "Invoice"
            }
          }
        }
      end

      let(:http_client) { instance_double(LagoHttpClient::Client) }
      let(:payment_service) { instance_double(Invoices::Payments::FlutterwaveService) }
      let(:verification_response_usd) do
        {
          "status" => "success",
          "data" => {
            "id" => 285959875,
            "tx_ref" => "lago_invoice_12345",
            "amount" => 100.50,
            "currency" => "USD",
            "charged_amount" => 100.50,
            "status" => "successful"
          }
        }
      end

      before do
        invoice
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_return(verification_response_usd)
        allow(Invoices::Payments::FlutterwaveService).to receive(:new).and_return(payment_service)
        allow(payment_service).to receive(:update_payment_status).and_return(instance_double("BaseService::Result", raise_if_error!: nil))
      end

      it "handles decimal amounts correctly" do
        charge_completed_service.call

        expect(payment_service).to have_received(:update_payment_status) do |args|
          metadata = args[:flutterwave_payment].metadata
          expect(metadata[:amount]).to eq(100.50)
          expect(metadata[:currency]).to eq("USD")
        end
      end
    end

    context "when webhook contains event.type field" do
      let(:payload) do
        {
          event: "charge.completed",
          data: {
            id: 285959875,
            tx_ref: "lago_invoice_12345",
            flw_ref: "LAGO/FLW270177170",
            amount: 10000,
            currency: "NGN",
            status: "successful",
            payment_type: "card",
            customer: {
              id: 215604089,
              name: "John Doe",
              email: "customer@example.com"
            },
            meta: {
              lago_invoice_id: invoice.id,
              lago_payable_type: "Invoice"
            }
          },
          "event.type": "CARD_TRANSACTION"
        }
      end

      let(:http_client) { instance_double(LagoHttpClient::Client) }
      let(:payment_service) { instance_double(Invoices::Payments::FlutterwaveService) }

      before do
        invoice
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_return(verification_response)
        allow(Invoices::Payments::FlutterwaveService).to receive(:new).and_return(payment_service)
        allow(payment_service).to receive(:update_payment_status).and_return(instance_double("BaseService::Result", raise_if_error!: nil))
      end

      it "processes the webhook normally" do
        result = charge_completed_service.call

        expect(payment_service).to have_received(:update_payment_status)
        expect(result).to be_success
      end
    end

    context "when meta field is missing" do
      let(:payload) do
        {
          event: "charge.completed",
          data: {
            id: 285959875,
            tx_ref: "lago_invoice_12345",
            flw_ref: "LAGO/FLW270177170",
            amount: 10000,
            currency: "NGN",
            status: "successful",
            payment_type: "card",
            customer: {
              id: 215604089,
              name: "John Doe",
              email: "customer@example.com"
            }
          }
        }
      end

      let(:http_client) { instance_double(LagoHttpClient::Client) }

      before do
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_return({"status" => "error"})
      end

      it "does not process the transaction" do
        result = charge_completed_service.call

        expect(result).to be_success
      end
    end
  end
end
