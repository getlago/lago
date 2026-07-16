# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::PaymentMethodsController do
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:external_id) { customer.external_id }
  let(:payment_method) { create(:payment_method, customer:, organization:) }

  describe "GET /api/v1/customers/:external_id/payment_methods" do
    subject { get_with_token(organization, "/api/v1/customers/#{external_id}/payment_methods", {}) }

    let(:second_payment_method) { create(:payment_method, organization:, customer:, is_default: false) }

    include_examples "requires API permission", "payment_method", "read"

    context "with unknown customer" do
      let(:external_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
        expect(json[:code]).to eq("customer_not_found")
      end
    end

    context "with customer from another organization" do
      let(:customer) { create(:customer) }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
        expect(json[:code]).to eq("customer_not_found")
      end
    end

    context "with payment methods" do
      before do
        payment_method
        second_payment_method
      end

      it "returns customer's payment methods" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:payment_methods].count).to eq(2)
        expect(json[:payment_methods].map { |r| r[:lago_id] }).to contain_exactly(
          payment_method.id,
          second_payment_method.id
        )
      end
    end
  end

  describe "PUT /api/v1/customers/:external_id/payment_methods/:id/set_as_default" do
    subject { put_with_token(organization, "/api/v1/customers/#{external_id}/payment_methods/#{payment_method.id}/set_as_default") }

    include_examples "requires API permission", "payment_method", "write"

    context "with unknown customer" do
      let(:external_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
        expect(json[:code]).to eq("customer_not_found")
      end
    end

    context "with unknown payment method" do
      subject { put_with_token(organization, "/api/v1/customers/#{external_id}/payment_methods/invalid/set_as_default") }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
        expect(json[:code]).to eq("payment_method_not_found")
      end
    end

    context "when payment method is already default" do
      let(:payment_method) { create(:payment_method, customer:, organization:, is_default: true) }
      let(:payment_method2) { create(:payment_method, customer:, organization:, is_default: false) }
      let(:payment_method3) { create(:payment_method, customer:, organization:, is_default: false) }

      before do
        payment_method
        payment_method2
        payment_method3
      end

      it "returns valid payment method" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:payment_method][:lago_id]).to eq(payment_method.id)
        expect(json[:payment_method][:is_default]).to eq(true)
        expect(payment_method.reload.is_default).to eq(true)
        expect(payment_method2.reload.is_default).to eq(false)
        expect(payment_method3.reload.is_default).to eq(false)
      end
    end

    context "when payment method is not default" do
      let(:payment_method) { create(:payment_method, customer:, organization:, is_default: false) }
      let(:payment_method2) { create(:payment_method, customer:, organization:, is_default: true) }
      let(:payment_method3) { create(:payment_method, customer:, organization:, is_default: false) }

      before do
        payment_method
        payment_method2
        payment_method3
      end

      it "sets payment method to default and returns valid payment method" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:payment_method][:lago_id]).to eq(payment_method.id)
        expect(json[:payment_method][:is_default]).to eq(true)
        expect(payment_method.reload.is_default).to eq(true)
        expect(payment_method2.reload.is_default).to eq(false)
        expect(payment_method3.reload.is_default).to eq(false)
      end
    end
  end

  describe "DELETE /api/v1/customers/:external_id/payment_methods/:id" do
    subject do
      delete_with_token(organization, "/api/v1/customers/#{external_id}/payment_methods/#{payment_method.id}")
    end

    let(:payment_method) { create(:payment_method, customer:, organization:, is_default: true) }

    include_examples "requires API permission", "payment_method", "write"

    context "with unknown customer" do
      let(:external_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
        expect(json[:code]).to eq("customer_not_found")
      end
    end

    context "with unknown payment method" do
      subject do
        delete_with_token(organization, "/api/v1/customers/#{external_id}/payment_methods/invalid")
      end

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
        expect(json[:code]).to eq("payment_method_not_found")
      end
    end

    context "with payment method" do
      it "sets payment method as NOT default" do
        expect { subject }
          .to change { payment_method.reload.is_default }
          .from(true)
          .to(false)
      end

      it "soft deletes the payment method" do
        freeze_time do
          expect { subject }.to change(PaymentMethod, :count).by(-1)
            .and change { payment_method.reload.deleted_at }.from(nil).to(Time.current)
        end
      end

      it "returns deleted payment method" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:payment_method][:lago_id]).to eq(payment_method.id)
      end
    end
  end
end
