# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::Payments::MoneyhashService do
  subject(:moneyhash_service) { described_class.new(payable) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }
  let(:moneyhash_customer) { create(:moneyhash_customer, customer:, payment_provider: moneyhash_provider) }
  let(:payable) do
    create(
      :payment_request,
      organization:,
      customer:,
      amount_cents: 799,
      amount_currency: "USD",
      invoices: [invoice_1, invoice_2]
    )
  end

  let(:invoice_1) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 200,
      currency: "USD",
      ready_for_payment_processing: true
    )
  end

  let(:invoice_2) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 599,
      currency: "USD",
      ready_for_payment_processing: true
    )
  end

  let(:payment_response_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/recurring_mit_payment_success_response.json"))) }
  let(:provider_payment_id) { payment_response_json.dig("data", "id") }

  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:response) { instance_double(Net::HTTPOK) }
  let(:endpoint) { "#{PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/payments/intent/" }
  let(:default_payment_method) do
    create(:payment_method, customer:, payment_provider_customer: moneyhash_customer, provider_method_id: "test_payment_method")
  end

  describe "#create" do
    before do
      moneyhash_provider
      moneyhash_customer
      default_payment_method
      allow(LagoHttpClient::Client).to receive(:new).with(endpoint).and_return(lago_client)
    end

    context "when moneyhash customer is missing provider customer id" do
      before { moneyhash_customer.update!(provider_customer_id: nil) }

      it "returns not found failure" do
        result = moneyhash_service.create

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("moneyhash_customer")
      end
    end

    context "when payment method is missing" do
      before { default_payment_method.update!(is_default: false) }

      it "returns not found failure" do
        result = moneyhash_service.create

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("payment_method")
      end
    end

    context "when there is no default payment method but the moneyhash customer has a legacy payment method id" do
      before do
        default_payment_method.update!(is_default: false)
        moneyhash_customer.update!(settings: moneyhash_customer.settings.merge("payment_method_id" => "legacy_mh_pm"))
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(payment_response_json.to_json)
      end

      it "processes the payment using the provider customer payment method id" do
        result = moneyhash_service.create

        expect(result).to be_success
        expect(result.payment).to be_present
        expect(lago_client).to have_received(:post_with_response)
          .with(hash_including(card_token: "legacy_mh_pm"), anything)
      end
    end

    context "when payment should not be processed" do
      context "when payment already succeeded" do
        before { payable.update!(payment_status: :succeeded) }

        it "returns success without payment" do
          result = moneyhash_service.create

          expect(result).to be_success
          expect(result.payment).to be_nil
        end
      end

      context "when moneyhash provider is missing" do
        before { moneyhash_provider.destroy }

        it "returns success without payment" do
          result = moneyhash_service.create

          expect(result).to be_success
          expect(result.payment).to be_nil
        end
      end
    end

    context "when payment amount is zero" do
      before { payable.update!(amount_cents: 0) }

      it "marks payment as succeeded without processing" do
        result = moneyhash_service.create

        expect(result).to be_success
        expect(result.payment).to be_nil
        expect(payable.reload.payment_status).to eq("succeeded")
      end
    end

    context "when payment should be processed" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(payment_response_json.to_json)
      end

      it "increments payment attempts, creates a payment and updates payment statuses for payable and invoices" do
        result = moneyhash_service.create

        expect(result).to be_success
        expect(result.payment).to be_present
        expect(result.payment.status).to eq("succeeded")
        expect(result.payment.provider_payment_id).to eq(provider_payment_id)
        expect(payable.reload.payment_status).to eq("succeeded")
        payable.invoices.each do |invoice|
          expect(invoice.payment_status).to eq("succeeded")
        end
      end

      context "when API request fails" do
        before do
          allow(lago_client).to receive(:post_with_response)
            .and_raise(LagoHttpClient::HttpError.new(422, "error", "error_code"))
        end

        it "marks payment as failed" do
          result = moneyhash_service.create

          expect(result).to be_success
          expect(result.payment).to be_nil
          expect(payable.reload.payment_status).to eq("failed")
          payable.invoices.each do |invoice|
            expect(invoice.payment_status).to eq("pending")
          end
        end
      end
    end

    context "when customer has a default payment method" do
      let(:default_payment_method) do
        create(:payment_method,
          customer:,
          payment_provider_customer: moneyhash_customer,
          provider_method_id: "pm_test_123")
      end

      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(payment_response_json.to_json)
      end

      it "uses customer default payment_method provider_method_id as card_token" do
        moneyhash_service.create

        expect(lago_client).to have_received(:post_with_response) do |params, _headers|
          expect(params[:card_token]).to eq("pm_test_123")
        end
      end
    end
  end

  describe "#update_payment_status" do
    let(:payment) do
      create(:payment,
        payment_provider: moneyhash_provider,
        provider_payment_id:,
        payable:,
        amount_cents: payable.total_amount_cents,
        amount_currency: payable.currency)
    end

    before do
      moneyhash_provider
      moneyhash_customer
      payable
      payment
      payment_response_json["data"]["custom_fields"]["lago_payable_id"] = payable.id
      payment_response_json["data"]["custom_fields"]["lago_payable_type"] = payable.class.name
    end

    context "when payment exists" do
      it "updates payment, payable and invoices status" do
        result = moneyhash_service.update_payment_status(
          organization_id: organization.id,
          provider_payment_id: payment_response_json.dig("data", "id"),
          status: payment_response_json.dig("data", "status"),
          metadata: payment_response_json.dig("data", "custom_fields")
        )

        expect(result).to be_success
        expect(result.payment.status).to eq("succeeded")
        expect(result.payment.provider_payment_id).to eq(payment_response_json.dig("data", "id"))
        expect(result.payable.payment_status).to eq("succeeded")
        [invoice_1, invoice_2].each do |invoice|
          expect(invoice.reload.payment_status).to eq("succeeded")
        end
      end
    end

    context "when payment does not exist" do
      let(:metadata) { {"lago_payable_id" => payable.id} }

      it "creates a new payment" do
        result = moneyhash_service.update_payment_status(
          organization_id: organization.id,
          provider_payment_id: "new_payment_id",
          status: "SUCCESSFUL",
          metadata:
        )

        expect(result).to be_success
        expect(result.payment).to be_present
        expect(result.payment.provider_payment_id).to eq("new_payment_id")
        expect(result.payment.status).to eq("succeeded")
        expect(result.payable.payment_status).to eq("succeeded")
        [invoice_1, invoice_2].each do |invoice|
          expect(invoice.reload.payment_status).to eq("succeeded")
        end
      end

      context "when payable is not found" do
        let(:metadata) { {"lago_payable_id" => "invalid_id"} }
        let(:moneyhash_service) { described_class.new(nil) }

        it "returns not found error" do
          result = moneyhash_service.update_payment_status(
            organization_id: organization.id,
            provider_payment_id: "new_payment_id",
            status: "SUCCESSFUL",
            metadata:
          )

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("payment_request")
        end
      end
    end

    context "when payment already succeeded" do
      before do
        payable.update!(payment_status: :succeeded)
        payment.update!(status: :succeeded)
      end

      it "does not update the status" do
        result = moneyhash_service.update_payment_status(
          organization_id: organization.id,
          provider_payment_id: payment_response_json.dig("data", "id"),
          status: "FAILED",
          metadata: payment_response_json.dig("data", "custom_fields")
        )

        expect(result).to be_success
        expect(payment.reload.status).to eq("succeeded")
        expect(payable.reload.payment_status).to eq("succeeded")
      end
    end

    context "when a failed webhook arrives after the invoices were already paid through another path" do
      before do
        payable.payment_failed!
        invoice_1.payment_succeeded!
        invoice_2.payment_succeeded!
      end

      it "leaves already-succeeded invoices untouched" do
        result = moneyhash_service.update_payment_status(
          organization_id: organization.id,
          provider_payment_id: payment_response_json.dig("data", "id"),
          status: "FAILED",
          metadata: payment_response_json.dig("data", "custom_fields")
        )

        expect(result).to be_success
        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_2.reload).to be_payment_succeeded
      end
    end
  end
end
