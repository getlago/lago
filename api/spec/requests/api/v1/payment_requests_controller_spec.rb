# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::PaymentRequestsController do
  let(:organization) { create(:organization) }

  describe "POST /api/v1/payment_requests" do
    subject do
      post_with_token(
        organization,
        "/api/v1/payment_requests",
        {payment_request: params}
      )
    end

    let(:customer) { create(:customer, organization:) }
    let(:invoice) { create(:invoice, organization:, customer:) }
    let(:params) do
      {
        email: customer.email,
        external_customer_id: customer.external_id,
        lago_invoice_ids: [invoice.id]
      }
    end

    let(:payment_request) { create(:payment_request, invoices: [invoice], customer:) }

    before do
      allow(PaymentRequests::CreateService).to receive(:call).and_return(
        BaseService::Result.new.tap { |r| r.payment_request = payment_request }
      )
    end

    include_examples "requires API permission", "payment_request", "write"

    it "delegates to PaymentRequests::CreateService" do
      subject

      expect(PaymentRequests::CreateService).to have_received(:call).with(
        organization:,
        params: {
          email: customer.email,
          external_customer_id: customer.external_id,
          lago_invoice_ids: [invoice.id]
        }
      )

      expect(response).to have_http_status(:success)
      expect(json[:payment_request][:lago_id]).to eq(payment_request.id)
      expect(json[:payment_request][:invoices].map { |i| i[:lago_id] }).to contain_exactly(invoice.id)
      expect(json[:payment_request][:customer][:lago_id]).to eq(customer.id)
    end
  end

  describe "GET /api/v1/payment_requests" do
    include_examples "a payment request index endpoint" do
      subject { get_with_token(organization, "/api/v1/payment_requests", params) }

      context "with external_customer_id filter" do
        let(:params) { {external_customer_id: customer.external_id} }

        before do
          payment_request
        end

        it "returns customer's payment requests" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:payment_requests].map { |r| r[:lago_id] }).to contain_exactly(
            payment_request.id
          )
          expect(json[:payment_requests].first[:customer][:lago_id]).to eq(customer.id)
        end

        context "with a not found customer" do
          let(:params) { {external_customer_id: SecureRandom.uuid} }

          before do
            payment_request
          end

          it "returns an empty result" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:payment_requests]).to be_empty
          end
        end
      end
    end

    context "when filtering by billing_entity_codes" do
      let(:billing_entity_eu) { create(:billing_entity, organization:, code: "EU") }
      let(:billing_entity_us) { create(:billing_entity, organization:, code: "US") }
      let(:customer_eu) { create(:customer, organization:) }
      let(:customer_us) { create(:customer, organization:) }
      let(:invoice_eu) { create(:invoice, organization:, customer: customer_eu, billing_entity: billing_entity_eu) }
      let(:invoice_us) { create(:invoice, organization:, customer: customer_us, billing_entity: billing_entity_us) }
      let(:payment_request_eu) do
        create(:payment_request, organization:, customer: customer_eu, invoices: [invoice_eu])
      end
      let(:payment_request_us) do
        create(:payment_request, organization:, customer: customer_us, invoices: [invoice_us])
      end

      before do
        payment_request_eu
        payment_request_us
      end

      it "returns only payment requests under the requested billing entity" do
        get_with_token(organization, "/api/v1/payment_requests?billing_entity_codes[]=EU")

        expect(response).to have_http_status(:success)
        expect(json[:payment_requests].map { |r| r[:lago_id] }).to contain_exactly(payment_request_eu.id)
      end

      context "when filtering by multiple billing_entity_codes" do
        it "returns payment requests matching any of the provided codes" do
          get_with_token(organization, "/api/v1/payment_requests?billing_entity_codes[]=EU&billing_entity_codes[]=US")

          expect(response).to have_http_status(:success)
          expect(json[:payment_requests].map { |r| r[:lago_id] }).to contain_exactly(
            payment_request_eu.id,
            payment_request_us.id
          )
        end
      end

      context "when one of the billing_entity_codes is unknown" do
        it "returns a not found error" do
          get_with_token(organization, "/api/v1/payment_requests?billing_entity_codes[]=EU&billing_entity_codes[]=BOGUS")

          expect(response).to be_not_found_error("billing_entity")
        end
      end
    end
  end

  describe "GET /api/v1/payment_requests/:id" do
    subject { get_with_token(organization, "/api/v1/payment_requests/#{id}") }

    let(:payment_request) { create(:payment_request, invoices: [invoice], customer:) }
    let(:customer) { create(:customer, organization:) }
    let(:invoice) { create(:invoice, organization:, customer:) }

    context "when payment request exists" do
      let(:id) { payment_request.id }

      include_examples "requires API permission", "payment_request", "read"

      it "returns the payment request" do
        subject
        expect(response).to have_http_status(:ok)
        expect(json[:payment_request][:lago_id]).to eq(payment_request.id)
        expect(json[:payment_request][:invoices].first[:lago_id]).to eq(invoice.id)
      end
    end

    context "when payment request does not exist" do
      let(:id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
