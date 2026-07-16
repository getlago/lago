# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Gocardless::Customers::CreateService do
  let(:create_service) { described_class.new(customer:, payment_provider_id:, params:, async:) }

  let(:customer) { create(:customer) }
  let(:gocardless_provider) { create(:gocardless_provider, organization: customer.organization) }
  let(:payment_provider_id) { gocardless_provider.id }

  let(:params) do
    {provider_customer_id: "id", sync_with_provider: true}
  end

  let(:async) { true }

  describe ".call" do
    it "creates a payment_provider_customer" do
      result = create_service.call

      expect(result).to be_success
      expect(result.provider_customer).to be_present
      expect(result.provider_customer.provider_customer_id).to eq("id")
    end

    context "when no provider customer id and should create on service" do
      let(:params) do
        {provider_customer_id: nil, sync_with_provider: true}
      end

      it "enqueues a job to create the customer on the provider" do
        expect { create_service.call }.to have_enqueued_job(PaymentProviderCustomers::GocardlessCreateJob)
      end
    end

    context "when removing the provider customer id and should create on service" do
      let(:params) do
        {provider_customer_id: nil, sync_with_provider: true}
      end

      let(:gocardless_customer) do
        create(
          :gocardless_customer,
          customer:,
          payment_provider: gocardless_provider
        )
      end

      before { gocardless_customer }

      it "updates the provider customer" do
        expect do
          result = create_service.call

          expect(result).to be_success

          expect(result.provider_customer.provider_customer_id).to be_nil
        end.not_to have_enqueued_job(PaymentProviderCustomers::GocardlessCreateJob)
      end
    end

    context "when provider customer id is set" do
      let(:params) do
        {provider_customer_id: "id", sync_with_provider:, provider_payment_methods: %w[card]}
      end

      before do
        allow(create_service).to receive(:generate_checkout_url).and_return(true)
        allow(create_service).to receive(:create_customer_on_provider_service).and_return(true)
      end

      context "when sync with provider is blank" do
        let(:sync_with_provider) { nil }
        let(:provider) { create(:gocardless_provider, organization: customer.organization) }

        context "when provider customer exists" do
          before do
            create(:gocardless_customer, customer:, payment_provider_id: provider.id)
          end

          it "generates checkout url" do
            create_service.call
            expect(create_service).to have_received(:generate_checkout_url)
          end

          it "does not create customer" do
            create_service.call
            expect(create_service).not_to have_received(:create_customer_on_provider_service)
          end
        end

        context "when provider customer does not exist" do
          it "does not generate checkout url" do
            create_service.call
            expect(create_service).not_to have_received(:generate_checkout_url)
          end

          it "does not create customer" do
            create_service.call
            expect(create_service).not_to have_received(:create_customer_on_provider_service)
          end
        end
      end

      context "when sync with provider is true" do
        let(:sync_with_provider) { true }

        it "does not generate checkout url" do
          create_service.call
          expect(create_service).not_to have_received(:generate_checkout_url)
        end

        it "does not enqueue a job to create the customer on the provider" do
          expect { create_service.call }.not_to enqueue_job(PaymentProviderCustomers::GocardlessCreateJob)
        end
      end
    end
  end
end
