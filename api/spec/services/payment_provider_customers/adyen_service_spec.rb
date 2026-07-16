# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::AdyenService do
  let(:adyen_service) { described_class.new(adyen_customer) }
  let(:customer) { create(:customer, organization:) }
  let(:adyen_provider) { create(:adyen_provider) }
  let(:organization) { adyen_provider.organization }
  let(:adyen_client) { instance_double(Adyen::Client) }
  let(:payment_links_api) { Adyen::PaymentLinksApi.new(adyen_client, 70) }
  let(:checkout) { Adyen::Checkout.new(adyen_client, 70) }
  let(:payment_links_response) { generate(:adyen_payment_links_response) }

  let(:adyen_customer) do
    create(:adyen_customer, customer:, provider_customer_id: nil)
  end

  before do
    allow(Adyen::Client).to receive(:new).and_return(adyen_client)
    allow(adyen_client).to receive(:checkout).and_return(checkout)
    allow(checkout).to receive(:payment_links_api).and_return(payment_links_api)
    allow(payment_links_api).to receive(:payment_links).and_return(payment_links_response)
  end

  describe "#create" do
    subject(:adyen_service_create) { adyen_service.create }

    context "when customer does not have an adyen customer id yet" do
      it "calls adyen api client payment links" do
        adyen_service_create
        expect(payment_links_api).to have_received(:payment_links)
      end

      it "creates a payment link" do
        expect(adyen_service_create.checkout_url).to eq("https://test.adyen.link/test")
      end

      it "delivers a success webhook" do
        expect { adyen_service_create }.to enqueue_job(SendWebhookJob)
          .with(
            "customer.checkout_url_generated",
            customer,
            checkout_url: "https://test.adyen.link/test"
          )
          .on_queue(webhook_queue)
      end
    end

    context "when customer already has an adyen customer id" do
      let(:adyen_customer) do
        create(:adyen_customer, customer:, provider_customer_id: "cus_123456")
      end

      it "does not call adyen API" do
        expect(payment_links_api).not_to have_received(:payment_links)
      end
    end

    context "when failing to generate the checkout link due to an error response" do
      let(:payment_links_error_response) { generate(:adyen_payment_links_error_response) }

      before do
        allow(payment_links_api).to receive(:payment_links).and_return(payment_links_error_response)
      end

      it "delivers an error webhook" do
        expect { adyen_service_create }.to enqueue_job(SendWebhookJob)
          .with(
            "customer.payment_provider_error",
            customer,
            provider_error: {
              message: "There are no payment methods available for the given parameters.",
              error_code: "validation"
            }
          ).on_queue(webhook_queue)
      end
    end

    context "when failing to generate the checkout link" do
      before do
        allow(payment_links_api)
          .to receive(:payment_links).and_raise(Adyen::AdyenError.new(nil, nil, "error"))
      end

      it "delivers an error webhook" do
        expect { adyen_service.create }
          .to raise_error(Adyen::AdyenError)

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "customer.payment_provider_error",
            customer,
            provider_error: {
              message: "error",
              error_code: nil
            }
          )
      end
    end

    context "with authentication error" do
      before do
        allow(payment_links_api)
          .to receive(:payment_links).and_raise(Adyen::AuthenticationError.new("error", nil))
      end

      it "delivers an error webhook" do
        expect(adyen_service.create).to be_success

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "customer.payment_provider_error",
            customer,
            provider_error: {
              message: "error",
              error_code: 401
            }
          )
      end
    end
  end

  describe "#update" do
    it "returns result" do
      expect(adyen_service.update).to be_a(BaseService::Result)
    end
  end

  describe "#success_redirect_url" do
    subject(:success_redirect_url) { adyen_service.__send__(:success_redirect_url) }

    context "when payment provider has success redirect url" do
      it "returns payment provider's success redirect url" do
        expect(success_redirect_url).to eq(adyen_provider.success_redirect_url)
      end
    end

    context "when payment provider has no success redirect url" do
      let(:adyen_provider) { create(:adyen_provider, success_redirect_url: nil) }

      it "returns the default success redirect url" do
        expect(success_redirect_url).to eq(PaymentProviders::AdyenProvider::SUCCESS_REDIRECT_URL)
      end
    end
  end

  describe "#generate_checkout_url" do
    context "when adyen payment provider is nil" do
      before { adyen_provider.destroy! }

      it "returns a not found error" do
        result = adyen_service.generate_checkout_url

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("adyen_payment_provider_not_found")
      end
    end

    context "when adyen payment provider is present" do
      subject(:generate_checkout_url) { adyen_service.generate_checkout_url }

      it "generates a checkout url" do
        expect(generate_checkout_url).to be_success
      end

      it "delivers a success webhook" do
        expect { generate_checkout_url }.to enqueue_job(SendWebhookJob)
          .with(
            "customer.checkout_url_generated",
            customer,
            checkout_url: "https://test.adyen.link/test"
          )
          .on_queue(webhook_queue)
      end

      context "when customer has no currency" do
        let(:customer) { create(:customer, organization:, currency: nil) }

        it "falls back to the organization default currency" do
          generate_checkout_url
          expect(payment_links_api).to have_received(:payment_links).with(
            hash_including(amount: hash_including(currency: organization.default_currency))
          )
        end
      end
    end
  end

  describe "#preauthorise" do
    subject(:preauthorise) { described_class.new.preauthorise(organization, event) }

    let(:payment_method_id) { "pm_adyen_123456" }
    let(:shopper_reference) { customer.external_id }

    let(:event) do
      {
        "success" => "true",
        "additionalData" => {
          "shopperReference" => shopper_reference,
          "recurring.recurringDetailReference" => payment_method_id
        }
      }
    end

    before { adyen_customer }

    context "when event is successful" do
      it "updates adyen_customer with payment_method_id and provider_customer_id" do
        preauthorise

        expect(adyen_customer.reload.payment_method_id).to eq(payment_method_id)
        expect(adyen_customer.provider_customer_id).to eq(shopper_reference)
      end

      it "delivers a success webhook" do
        expect { preauthorise }.to enqueue_job(SendWebhookJob)
          .with("customer.payment_provider_created", customer)
          .on_queue(webhook_queue)
      end

      it "creates a new PaymentMethod record" do
        expect { preauthorise }.to change(PaymentMethod, :count).by(1)

        payment_method = PaymentMethod.last
        expect(payment_method.customer).to eq(customer)
        expect(payment_method.payment_provider_customer).to eq(adyen_customer)
        expect(payment_method.provider_method_id).to eq(payment_method_id)
        expect(payment_method.provider_method_type).to eq("card")
        expect(payment_method.is_default).to be(true)
      end

      context "when PaymentMethod already exists" do
        let!(:existing_payment_method) do
          create(
            :payment_method,
            customer:,
            payment_provider_customer: adyen_customer,
            provider_method_id: payment_method_id,
            is_default: false
          )
        end

        it "does not create a new PaymentMethod" do
          expect { preauthorise }.not_to change(PaymentMethod, :count)
        end

        it "sets the existing PaymentMethod as default" do
          preauthorise

          expect(existing_payment_method.reload.is_default).to be(true)
        end

        context "when payment method lookup raises RecordNotUnique" do
          before do
            allow(PaymentMethods::FindOrCreateFromProviderService).to receive(:call).and_raise(ActiveRecord::RecordNotUnique)
          end

          it "does not raise error" do
            expect { preauthorise }.not_to raise_error(ActiveRecord::RecordNotUnique)
          end
        end
      end
    end

    context "when event is not successful" do
      let(:event) do
        {
          "success" => "false",
          "reason" => "Refused",
          "eventCode" => "AUTHORISATION",
          "additionalData" => {
            "shopperReference" => shopper_reference,
            "recurring.recurringDetailReference" => payment_method_id
          }
        }
      end

      it "does not update adyen_customer" do
        preauthorise

        expect(adyen_customer.reload.payment_method_id).to be_nil
      end

      it "delivers an error webhook" do
        expect { preauthorise }.to enqueue_job(SendWebhookJob)
          .with(
            "customer.payment_provider_error",
            customer,
            provider_error: {
              message: "Refused",
              error_code: "AUTHORISATION"
            }
          )
          .on_queue(webhook_queue)
      end
    end

    context "when adyen_customer is not found" do
      let(:shopper_reference) { "unknown_customer" }

      it "returns a successful result without updating" do
        result = preauthorise

        expect(result).to be_success
      end
    end
  end
end
