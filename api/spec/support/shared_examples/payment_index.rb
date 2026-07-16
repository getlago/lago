# frozen_string_literal: true

RSpec.shared_examples "a payment index endpoint" do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  let(:params) { {} }

  include_examples "requires API permission", "payment", "read"

  it "returns customer's payments" do
    invoice = create(:invoice, organization:, customer:)
    invoice2 = create(:invoice, organization:, customer:)
    payment_request = create(:payment_request, organization:, customer:)
    first_payment = create(:payment, payable: invoice, customer:)
    second_payment = create(:payment, payable: invoice2, customer:)
    third_payment = create(:payment, payable: payment_request, customer:)

    subject

    expect(response).to have_http_status(:success)
    expect(json[:payments].count).to eq(3)
    expect(json[:payments].map { |r| r[:lago_id] }).to contain_exactly(
      first_payment.id,
      second_payment.id,
      third_payment.id
    )
  end

  context "with invoice_id filter" do
    let(:invoice) { create(:invoice, organization:, customer:) }
    let(:params) { {invoice_id: invoice.id} }
    let(:first_payment) { create(:payment, payable: invoice, customer:) }

    before do
      first_payment
      create(:payment)
    end

    it "returns invoice's payments" do
      subject
      expect(response).to have_http_status(:success)
      expect(json[:payments].map { |r| r[:lago_id] }).to contain_exactly(first_payment.id)
      expect(json[:payments].first[:invoice_ids].first).to eq(invoice.id)
    end
  end
end
