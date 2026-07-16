# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderFormsQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:, search_term:)
  end

  let(:returned_ids) { result.order_forms.pluck(:id) }
  let(:pagination) { nil }
  let(:filters) { nil }
  let(:search_term) { nil }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:quote_version) { create(:quote_version, quote:, organization:) }
  let(:order_form_one) { create(:order_form, organization:, customer:, quote_version:) }
  let(:order_form_two) { create(:order_form, organization:, customer:) }

  before do
    order_form_one
    order_form_two
  end

  it "returns all order forms for the organization" do
    expect(result).to be_success
    expect(returned_ids).to match_array([order_form_one.id, order_form_two.id])
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 1} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.order_forms.count).to eq(1)
      expect(result.order_forms.current_page).to eq(2)
      expect(result.order_forms.total_pages).to eq(2)
      expect(result.order_forms.total_count).to eq(2)
    end
  end

  context "when filtering by status" do
    let(:order_form_two) { create(:order_form, :signed, organization:, customer:) }
    let(:filters) { {status: "generated"} }

    it "returns only order forms with the specified status" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_form_one.id])
    end
  end

  context "when filtering by customer_id" do
    let(:other_customer) { create(:customer, organization:) }
    let(:other_quote) { create(:quote, organization:, customer: other_customer) }
    let(:other_quote_version) { create(:quote_version, quote: other_quote, organization:) }
    let(:order_form_two) { create(:order_form, organization:, customer: other_customer, quote_version: other_quote_version) }
    let(:filters) { {customer_id: [customer.id]} }

    it "returns only order forms for the specified customer" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_form_one.id])
    end
  end

  context "when filtering by number" do
    let(:filters) { {number: [order_form_one.number]} }

    it "returns only order forms with the specified numbers" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_form_one.id])
    end
  end

  context "when filtering by quote_number" do
    let(:other_customer) { create(:customer, organization:) }
    let(:other_quote) { create(:quote, organization:, customer: other_customer) }
    let(:other_quote_version) { create(:quote_version, quote: other_quote, organization:) }
    let(:order_form_two) { create(:order_form, organization:, customer: other_customer, quote_version: other_quote_version) }
    let(:filters) { {quote_number: [quote.number]} }

    it "returns only order forms linked to the specified quote" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_form_one.id])
    end
  end

  context "when filtering by owner_id" do
    let(:user) { membership.user }
    let(:other_customer) { create(:customer, organization:) }
    let(:other_quote) { create(:quote, organization:, customer: other_customer) }
    let(:other_quote_version) { create(:quote_version, quote: other_quote, organization:) }
    let(:order_form_two) { create(:order_form, organization:, customer: other_customer, quote_version: other_quote_version) }
    let(:filters) { {owner_id: [user.id]} }

    before { QuoteOwner.create!(organization:, quote:, user:) }

    it "returns only order forms whose quote has the specified owner" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_form_one.id])
    end
  end

  context "when filtering by created_at range" do
    let(:order_form_one) { create(:order_form, organization:, customer:, created_at: 3.days.ago) }
    let(:order_form_two) { create(:order_form, organization:, customer:, created_at: 1.day.ago) }
    let(:filters) { {created_at_from: 2.days.ago.iso8601, created_at_to: Time.current.iso8601} }

    it "returns only order forms within the date range" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_form_two.id])
    end
  end

  context "when filtering by expires_at range" do
    let(:order_form_one) { create(:order_form, organization:, customer:, expires_at: 5.days.from_now) }
    let(:order_form_two) { create(:order_form, organization:, customer:, expires_at: 15.days.from_now) }
    let(:filters) { {expires_at_from: 3.days.from_now.iso8601, expires_at_to: 10.days.from_now.iso8601} }

    it "returns only order forms expiring within the date range" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_form_one.id])
    end
  end

  context "with search_term on number" do
    let(:search_term) { order_form_one.number }

    it "returns matching order forms" do
      expect(result).to be_success
      expect(returned_ids).to eq([order_form_one.id])
    end
  end

  context "when no order forms exist" do
    before { OrderForm.delete_all }

    it "returns an empty result set" do
      expect(result).to be_success
      expect(returned_ids).to be_empty
    end
  end

  context "when filters are invalid" do
    let(:filters) { {status: "invalid_status"} }

    it "returns a validation failure" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages[:status]).to be_present
    end
  end

  context "when a date filter is accepted by the contract but unparseable by the query" do
    # The filters contract coerces with the lenient :time type, but the query
    # re-parses the raw string with the stricter DateTime.iso8601. A space-separated
    # datetime passes the contract yet raises in the query.
    let(:filters) { {created_at_from: "2026-01-01 10:00:00"} }

    it "returns a validation failure instead of raising" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages[:created_at_from]).to include("invalid_date")
    end
  end

  context "when order forms belong to another organization" do
    let(:other_organization) { create(:organization) }
    let(:other_customer) { create(:customer, organization: other_organization) }
    let(:other_quote) { create(:quote, organization: other_organization, customer: other_customer) }
    let(:other_quote_version) { create(:quote_version, quote: other_quote, organization: other_organization) }

    before do
      create(:order_form, organization: other_organization, customer: other_customer, quote_version: other_quote_version)
    end

    it "does not return order forms from other organizations" do
      expect(result).to be_success
      expect(returned_ids).to match_array([order_form_one.id, order_form_two.id])
    end
  end
end
