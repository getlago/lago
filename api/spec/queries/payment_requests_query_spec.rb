# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequestsQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:)
  end

  let(:returned_ids) { result.payment_requests.pluck(:id) }

  let(:pagination) { nil }
  let(:filters) { {} }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:payment_request_first) { create(:payment_request, organization:) }
  let(:payment_request_second) { create(:payment_request, organization:, customer:) }

  before do
    payment_request_first
    payment_request_second
  end

  it "returns all payment requests" do
    expect(result).to be_success
    expect(result.payment_requests.pluck(:id)).to contain_exactly(
      payment_request_first.id,
      payment_request_second.id
    )
  end

  context "when payment requests have the same values for the ordering criteria" do
    let(:payment_request_second) do
      create(
        :payment_request,
        organization:,
        customer:,
        id: "00000000-0000-0000-0000-000000000000",
        created_at: payment_request_first.created_at
      )
    end

    it "returns a consistent list" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(2)
      expect(returned_ids).to include(payment_request_first.id)
      expect(returned_ids).to include(payment_request_second.id)
      expect(returned_ids.index(payment_request_first.id)).to be > returned_ids.index(payment_request_second.id)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 1} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.payment_requests.count).to eq(1)
      expect(result.payment_requests.current_page).to eq(2)
      expect(result.payment_requests.prev_page).to eq(1)
      expect(result.payment_requests.next_page).to be_nil
      expect(result.payment_requests.total_pages).to eq(2)
      expect(result.payment_requests.total_count).to eq(2)
    end
  end

  context "when filtering by customer_id" do
    let(:filters) { {external_customer_id: customer.external_id} }

    it "returns all payment_requests of the customer" do
      expect(result).to be_success
      expect(result.payment_requests.pluck(:id)).to contain_exactly(
        payment_request_second.id
      )
    end
  end

  context "when filtering by currency" do
    let(:filters) { {currency: "BRL"} }
    let(:payment_request_first) { create(:payment_request, organization:, amount_currency: "BRL") }
    let(:payment_request_second) { create(:payment_request, organization:, customer:, amount_currency: "EUR") }

    it "returns only payment requests with matching currency" do
      expect(result).to be_success
      expect(result.payment_requests.pluck(:id)).to eq([payment_request_first.id])
    end

    context "when no payment requests match the currency" do
      let(:filters) { {currency: "GBP"} }

      it "returns no payment requests" do
        expect(result).to be_success
        expect(result.payment_requests.count).to eq(0)
      end
    end
  end

  context "when filtering by billing_entity_ids" do
    let(:billing_entity_eu) { create(:billing_entity, organization:, code: "EU") }
    let(:billing_entity_us) { create(:billing_entity, organization:, code: "US") }

    let(:customer_first) { create(:customer, organization:) }
    let(:customer_second) { create(:customer, organization:) }

    let(:invoice_eu) { create(:invoice, organization:, customer: customer_first, billing_entity: billing_entity_eu) }
    let(:invoice_us) { create(:invoice, organization:, customer: customer_second, billing_entity: billing_entity_us) }

    let(:payment_request_first) do
      create(:payment_request, organization:, customer: customer_first, invoices: [invoice_eu])
    end
    let(:payment_request_second) do
      create(:payment_request, organization:, customer: customer_second, invoices: [invoice_us])
    end

    let(:filters) { {billing_entity_ids: [billing_entity_eu.id]} }

    it "returns payment requests whose invoices belong to the billing entity" do
      expect(result).to be_success
      expect(returned_ids).to contain_exactly(payment_request_first.id)
    end

    context "with multiple billing_entity_ids" do
      let(:filters) { {billing_entity_ids: [billing_entity_eu.id, billing_entity_us.id]} }

      it "returns payment requests matching any of the provided ids" do
        expect(returned_ids).to contain_exactly(
          payment_request_first.id,
          payment_request_second.id
        )
      end
    end

    context "when a payment request has multiple invoices in the same billing entity" do
      let(:second_invoice_eu) do
        create(:invoice, organization:, customer: customer_first, billing_entity: billing_entity_eu)
      end
      let(:payment_request_first) do
        create(
          :payment_request,
          organization:,
          customer: customer_first,
          invoices: [invoice_eu, second_invoice_eu]
        )
      end

      it "does not return duplicates" do
        expect(returned_ids.count(payment_request_first.id)).to eq(1)
      end
    end

    context "when no payment request matches the billing entity" do
      let(:filters) { {billing_entity_ids: [create(:billing_entity, organization:).id]} }

      it "returns no payment requests" do
        expect(result).to be_success
        expect(returned_ids).to be_empty
      end
    end
  end

  context "when filtering by payment_status" do
    context "when pending status" do
      let(:filters) { {payment_status: :pending} }

      it "returns all payment_requests with status pending" do
        expect(result).to be_success
        expect(result.payment_requests.count).to eq(2)
        expect(result.payment_requests.pluck(:id)).to contain_exactly(
          payment_request_first.id,
          payment_request_second.id
        )
      end
    end

    context "when succeeded status" do
      let(:filters) { {payment_status: :succeeded} }

      before { payment_request_second.payment_succeeded! }

      it "returns all payment_requests with status pending" do
        expect(result).to be_success
        expect(result.payment_requests.count).to eq(1)
        expect(result.payment_requests.pluck(:id)).to contain_exactly(
          payment_request_second.id
        )
      end
    end
  end
end
