# frozen_string_literal: true

RSpec.shared_examples "a payment request index endpoint" do
  let(:organization) { create(:organization) }
  let(:params) { {} }

  let(:customer) { create(:customer, organization:) }
  let(:payment_request) { create(:payment_request, customer:) }
  let(:second_payment_request) { create(:payment_request, customer:) }

  include_examples "requires API permission", "payment_request", "read"

  context "without filters" do
    before do
      payment_request
      second_payment_request
    end

    it "returns organization's payment requests" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:payment_requests].count).to eq(2)
      expect(json[:payment_requests].map { |r| r[:lago_id] }).to contain_exactly(
        payment_request.id,
        second_payment_request.id
      )
    end
  end

  context "with currency filter" do
    let!(:usd_payment_request) { create(:payment_request, customer:, amount_currency: "USD") }
    let(:params) { {currency: "EUR"} }

    before do
      payment_request
      usd_payment_request
    end

    it "returns only payment requests with matching currency" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:payment_requests].count).to eq(1)
      expect(json[:payment_requests].first[:lago_id]).to eq(payment_request.id)
    end
  end

  context "with payment_status filter" do
    let(:second_payment_request) { create(:payment_request, :succeeded, customer:) }
    let(:params) { {payment_status: "pending"} }

    before do
      payment_request
      second_payment_request
    end

    it "returns payment requests with the given payment status" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:payment_requests].count).to eq(1)
      expect(json[:payment_requests].map { |r| r[:lago_id] }).to contain_exactly(
        payment_request.id
      )
    end
  end
end
