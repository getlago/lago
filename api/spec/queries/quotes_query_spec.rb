# frozen_string_literal: true

require "rails_helper"

RSpec.describe QuotesQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:)
  end

  let(:returned_ids) { result.quotes.pluck(:id) }
  let(:pagination) { nil }
  let(:filters) { {} }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:quote_draft) { create(:quote, :with_version, organization:, customer:, created_at: 8.days.ago) }
  let(:quote_approved) { create(:quote, :with_version, version_trait: :approved, organization:, customer:, created_at: 6.days.ago) }
  let(:quote_voided) { create(:quote, :with_version, version_trait: :voided, organization:, customer:, created_at: 4.days.ago) }

  before do
    quote_draft
    quote_approved
    quote_voided
  end

  it "returns all quotes" do
    expect(returned_ids.count).to eq(3)
    expect(returned_ids).to include(quote_draft.id)
    expect(returned_ids).to include(quote_approved.id)
    expect(returned_ids).to include(quote_voided.id)
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.quotes.count).to eq(1)
      expect(result.quotes.current_page).to eq(2)
      expect(result.quotes.prev_page).to eq(1)
      expect(result.quotes.next_page).to be_nil
      expect(result.quotes.total_pages).to eq(2)
      expect(result.quotes.total_count).to eq(3)
    end
  end

  context "when filtering" do
    describe "customers" do
      context "when filtering by valid customer" do
        let(:other_customer) { create(:customer, organization:) }
        let(:other_quote) { create(:quote, :with_version, organization:, customer: other_customer) }
        let(:filters) { {customers: [other_customer.id]} }

        before do
          other_quote
        end

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(other_quote.id)
        end
      end

      context "when filtering by invalid customer" do
        let(:filters) { {customers: ["invalid_customer"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "external_customer_ids" do
      context "when filtering by an existing external customer id" do
        let(:other_customer) { create(:customer, organization:) }
        let(:other_quote) { create(:quote, :with_version, organization:, customer: other_customer) }
        let(:filters) { {external_customer_ids: [other_customer.external_id]} }

        before do
          other_quote
        end

        it "returns only that customer's quotes" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(other_quote.id)
        end
      end

      context "when filtering by an unknown external customer id" do
        let(:filters) { {external_customer_ids: ["unknown"]} }

        it "returns no quotes" do
          expect(result).to be_success
          expect(returned_ids).to be_empty
        end
      end
    end

    describe "statuses" do
      context "when filtering by valid status" do
        let(:filters) { {statuses: ["draft"]} }

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(quote_draft.id)
        end
      end

      context "when filtering by invalid status" do
        let(:filters) { {statuses: ["invalid_status"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "numbers" do
      context "when filtering by valid number" do
        let(:other_quote) { create(:quote, :with_version, organization:) }
        let(:filters) { {numbers: [other_quote.number]} }

        before do
          other_quote
        end

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(other_quote.id)
        end
      end

      context "when filtering by invalid number" do
        let(:filters) { {numbers: ["invalid_number"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "date range" do
      context "when filtering by valid date range" do
        let(:filters) do
          {
            from_date: 2.days.ago.iso8601,
            to_date: 1.day.ago.iso8601
          }
        end

        it "returns quotes updated within the date range" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(0)
        end
      end

      context "when filtering with invalid date format" do
        let(:filters) do
          {
            from_date: "invalid_date",
            to_date: "invalid_date"
          }
        end

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "owners" do
      context "when filtering by valid owners" do
        let(:membership) { create(:membership, organization:) }
        let(:other_quote) { create(:quote, :with_version, organization:) }
        let(:filters) { {owners: [membership.user.id]} }

        before do
          QuoteOwner.create!(organization:, quote: other_quote, user: membership.user)
        end

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(other_quote.id)
        end
      end

      context "when filtering by invalid owners" do
        let(:filters) { {owners: ["invalid_owner"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "order_types" do
      let(:one_off_quote) { create(:quote, :with_version, organization:, customer:, order_type: :one_off) }

      before do
        one_off_quote
      end

      context "when filtering by valid order_types" do
        let(:filters) { {order_types: ["one_off"]} }

        it "returns only quotes with the matching order type" do
          expect(result).to be_success
          expect(returned_ids).to eq([one_off_quote.id])
        end
      end

      context "when filtering by invalid order_types" do
        let(:filters) { {order_types: ["invalid_order_type"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end
  end
end
