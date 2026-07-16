# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrdersQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:, search_term:)
  end

  let(:returned_ids) { result.orders.pluck(:id) }
  let(:pagination) { nil }
  let(:filters) { nil }
  let(:search_term) { nil }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:order_form) { create(:order_form, :signed, organization:, customer:, quote:) }
  let(:order_one) { create(:order, organization:, customer:, order_form:) }
  let(:quote_two) { create(:quote, organization:, customer:) }
  let(:order_form_two) { create(:order_form, :signed, organization:, customer:, quote: quote_two) }
  let(:order_two) { create(:order, organization:, customer:, order_form: order_form_two) }

  before do
    order_one
    order_two
  end

  it "returns all orders for the organization" do
    expect(result).to be_success
    expect(returned_ids).to match_array([order_one.id, order_two.id])
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 1} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.orders.count).to eq(1)
      expect(result.orders.current_page).to eq(2)
      expect(result.orders.total_pages).to eq(2)
      expect(result.orders.total_count).to eq(2)
    end
  end

  context "when filtering by status" do
    let(:filters) { {status: "created"} }

    it "returns only orders with the specified status" do
      expect(result).to be_success
      expect(returned_ids).to match_array([order_one.id, order_two.id])
    end
  end

  context "when filtering by order_type" do
    let(:one_off_quote) { create(:quote, organization:, customer:, order_type: :one_off) }
    let(:order_form_two) { create(:order_form, :signed, organization:, customer:, quote: one_off_quote) }
    let(:filters) { {order_type: "one_off"} }

    it "returns only orders with the specified order type" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_two.id])
    end
  end

  context "when filtering by customer_id" do
    let(:other_customer) { create(:customer, organization:) }
    let(:other_quote) { create(:quote, organization:, customer: other_customer) }
    let(:other_order_form) { create(:order_form, :signed, organization:, customer: other_customer, quote: other_quote) }
    let(:order_two) { create(:order, organization:, customer: other_customer, order_form: other_order_form) }
    let(:filters) { {customer_id: [customer.id]} }

    it "returns only orders for the specified customer" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_one.id])
    end
  end

  context "when filtering by execution_mode" do
    let(:order_two) { create(:order, organization:, customer:, order_form: order_form_two, execution_mode: :order_only) }
    let(:filters) { {execution_mode: "order_only"} }

    it "returns only orders with the specified execution mode" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_two.id])
    end
  end

  context "when filtering by number" do
    let(:filters) { {number: [order_one.number]} }

    it "returns only orders with the specified numbers" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_one.id])
    end
  end

  context "when filtering by order_form_number" do
    let(:filters) { {order_form_number: [order_form.number]} }

    it "returns only orders linked to the specified order form" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_one.id])
    end
  end

  context "when filtering by quote_number" do
    let(:other_customer) { create(:customer, organization:) }
    let(:other_quote) { create(:quote, organization:, customer: other_customer) }
    let(:other_order_form) { create(:order_form, :signed, organization:, customer: other_customer, quote: other_quote) }
    let(:order_two) { create(:order, organization:, customer: other_customer, order_form: other_order_form) }
    let(:filters) { {quote_number: [quote.number]} }

    it "returns only orders linked to the specified quote" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_one.id])
    end
  end

  context "when filtering by owner_id" do
    let(:user) { membership.user }
    let(:other_customer) { create(:customer, organization:) }
    let(:other_quote) { create(:quote, organization:, customer: other_customer) }
    let(:other_order_form) { create(:order_form, :signed, organization:, customer: other_customer, quote: other_quote) }
    let(:order_two) { create(:order, organization:, customer: other_customer, order_form: other_order_form) }
    let(:filters) { {owner_id: [user.id]} }

    before { QuoteOwner.create!(organization:, quote:, user:) }

    it "returns only orders whose quote has the specified owner" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_one.id])
    end
  end

  context "when filtering by executed_at range" do
    let(:order_one) { create(:order, organization:, customer:, order_form:, executed_at: 3.days.ago) }
    let(:order_two) { create(:order, organization:, customer:, order_form: order_form_two, executed_at: 1.day.ago) }
    let(:filters) { {executed_at_from: 2.days.ago.iso8601, executed_at_to: Time.current.iso8601} }

    it "returns only orders within the date range" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_two.id])
    end
  end

  context "with search_term on number" do
    let(:search_term) { order_one.number }

    it "returns matching orders" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_one.id])
    end
  end

  context "when no orders exist" do
    before { Order.delete_all }

    it "returns an empty result set" do
      expect(result).to be_success
      expect(returned_ids).to be_empty
    end
  end
end
