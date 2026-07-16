# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethods::FindOrCreateFromProviderService do
  subject(:service) do
    described_class.new(
      customer:,
      payment_provider_customer:,
      provider_method_id:,
      params:,
      set_as_default:
    )
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:payment_provider_customer) { create(:stripe_customer, customer:) }
  let(:provider_method_id) { "pm_123456" }
  let(:params) { {} }
  let(:set_as_default) { false }

  describe "#call" do
    context "without provider_method_id" do
      let(:provider_method_id) { nil }

      it "returns success without creating a PaymentMethod" do
        expect { service.call }.not_to change(PaymentMethod, :count)

        result = service.call
        expect(result).to be_success
        expect(result.payment_method).to be_nil
      end
    end

    context "when PaymentMethod does not exist" do
      it "creates a new PaymentMethod" do
        expect { service.call }.to change(PaymentMethod, :count).by(1)
      end

      it "returns the created PaymentMethod" do
        result = service.call

        expect(result).to be_success
        expect(result.payment_method).to be_present
        expect(result.payment_method.customer).to eq(customer)
        expect(result.payment_method.payment_provider_customer).to eq(payment_provider_customer)
        expect(result.payment_method.provider_method_id).to eq(provider_method_id)
        expect(result.payment_method.provider_method_type).to eq("card")
      end

      context "with provider_payment_methods in params" do
        let(:params) { {provider_payment_methods: %w[sepa_debit card]} }

        it "uses the first payment method type from params" do
          result = service.call

          expect(result.payment_method.provider_method_type).to eq("sepa_debit")
        end
      end
    end

    context "when PaymentMethod already exists" do
      let!(:existing_payment_method) do
        create(
          :payment_method,
          customer:,
          payment_provider_customer:,
          provider_method_id:,
          is_default: false
        )
      end

      it "does not create a new PaymentMethod" do
        expect { service.call }.not_to change(PaymentMethod, :count)
      end

      it "returns the existing PaymentMethod" do
        result = service.call

        expect(result).to be_success
        expect(result.payment_method).to eq(existing_payment_method)
      end

      it "does not change is_default by default" do
        service.call

        expect(existing_payment_method.reload.is_default).to be(false)
      end
    end

    context "when a concurrent process creates the same PaymentMethod" do
      it "rescues RecordNotUnique and returns the existing record" do
        allow(PaymentMethods::CreateFromProviderService).to receive(:call).and_raise(ActiveRecord::RecordNotUnique)

        existing_payment_method = create(
          :payment_method,
          customer:,
          payment_provider_customer:,
          provider_method_id:
        )

        result = service.call

        expect(result).to be_success
        expect(result.payment_method).to eq(existing_payment_method)
      end
    end

    context "with set_as_default: true" do
      let(:set_as_default) { true }

      context "when PaymentMethod does not exist" do
        it "creates PaymentMethod and sets as default" do
          result = service.call

          expect(result.payment_method.is_default).to be(true)
        end
      end

      context "when PaymentMethod already exists" do
        let!(:existing_payment_method) do
          create(
            :payment_method,
            customer:,
            payment_provider_customer:,
            provider_method_id:,
            is_default: false
          )
        end

        it "sets the existing PaymentMethod as default" do
          service.call

          expect(existing_payment_method.reload.is_default).to be(true)
        end
      end

      context "when PaymentMethod is already default" do
        let!(:existing_payment_method) do
          create(
            :payment_method,
            customer:,
            payment_provider_customer:,
            provider_method_id:,
            is_default: true
          )
        end

        it "returns the existing PaymentMethod without changes" do
          result = service.call

          expect(result).to be_success
          expect(result.payment_method).to eq(existing_payment_method)
          expect(existing_payment_method.reload.is_default).to be(true)
        end
      end
    end
  end
end
