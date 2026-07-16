# frozen_string_literal: true

require "rails_helper"

RSpec.describe CustomersQuery do
  subject(:result) do
    described_class.call(organization:, search_term:, pagination:, filters:)
  end

  let(:returned_ids) { result.customers.pluck(:id) }
  let(:pagination) { nil }
  let(:search_term) { nil }
  let(:filters) { {} }
  let(:organization) { create(:organization) }
  let(:billing_entity1) { organization.default_billing_entity }
  let(:billing_entity2) { create(:billing_entity, organization:) }

  let(:customer_first) do
    create(
      :customer,
      organization:,
      name: "defgh",
      firstname: "John",
      lastname: "Doe",
      legal_name: "Legalname",
      external_id: "11",
      email: "1@example.com",
      country: "US",
      state: "CA",
      zipcode: "90001",
      billing_entity: billing_entity1,
      currency: "USD",
      tax_identification_number: "US123456789",
      customer_type: "company"
    )
  end
  let(:customer_second) do
    create(
      :customer,
      organization:,
      name: "abcde",
      firstname: "Jane",
      lastname: "Smith",
      legal_name: "other name",
      external_id: "22",
      email: "2@example.com",
      country: "FR",
      state: "Paris",
      zipcode: "75001",
      billing_entity: billing_entity1,
      currency: "EUR",
      customer_type: "individual"
    )
  end
  let(:customer_third) do
    create(
      :customer,
      organization:,
      account_type: "partner",
      email: "3@example.com",
      external_id: "33",
      firstname: "Mary",
      lastname: "Johnson",
      legal_name: "Company name",
      name: "presuv",
      country: "DE",
      state: "Berlin",
      zipcode: "10115",
      billing_entity: billing_entity2,
      currency: "EUR",
      customer_type: nil
    )
  end

  before do
    customer_first
    customer_second
    customer_third

    create(:customer_metadata, customer: customer_first, key: "id", value: "1")
    create(:customer_metadata, customer: customer_first, key: "name", value: "John Doe")
    create(:customer_metadata, customer: customer_second, key: "id", value: "2")
  end

  it "returns all customers" do
    expect(result).to be_success
    expect(returned_ids.count).to eq(3)
    expect(returned_ids).to include(customer_first.id)
    expect(returned_ids).to include(customer_second.id)
    expect(returned_ids).to include(customer_third.id)
  end

  context "when filtering by external_id" do
    let(:filters) { {external_id: customer_first.external_id} }

    it "returns the customer with matching external_id" do
      expect(result.customers).to match_array([customer_first])
    end

    context "when search_term is present" do
      let(:search_term) { customer_second.external_id }

      it "ignores the search_term" do
        expect(result.customers).to match_array([customer_first])
      end
    end
  end

  context "when filtering by customer_type" do
    context "when filtering by company" do
      let(:filters) { {customer_type: "company"} }

      it "returns company customers" do
        expect(returned_ids.count).to eq(1)
        expect(returned_ids).to eq [customer_first.id]
      end
    end

    context "when filtering by individual" do
      let(:filters) { {customer_type: "individual"} }

      it "returns the customers with nil customer_type" do
        expect(returned_ids).to eq([customer_second.id])
      end
    end

    context "when filtering with invalid customer_type" do
      let(:filters) { {customer_types: %w[invalid]} }

      it "returns the customers with nil customer_type" do
        expect(returned_ids.count).to eq(3)
      end
    end
  end

  context "when filtering by has_customer_type" do
    context "when filtering by true" do
      let(:filters) { {has_customer_type: true} }

      it "returns the customers with customer_type" do
        expect(returned_ids).to match_array([customer_first.id, customer_second.id])
      end
    end

    context "when filtering by false" do
      let(:filters) { {has_customer_type: false} }

      it "returns the customers with nil customer_type" do
        expect(returned_ids).to eq([customer_third.id])
      end
    end
  end

  context "when filtering by partner account_type" do
    let(:filters) { {account_type: %w[partner]} }

    it "returns partner accounts" do
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).to eq [customer_third.id]
    end
  end

  context "when filtering by customer account_type" do
    let(:filters) { {account_type: %w[customer]} }

    it "returns customer accounts" do
      expect(returned_ids.count).to eq(2)
      expect(returned_ids).to include customer_first.id
      expect(returned_ids).to include customer_second.id
    end
  end

  context "when filtering by billing_entity_id" do
    let(:filters) { {billing_entity_ids: [billing_entity2.id]} }

    it "returns customers for the specified billing entity" do
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).to include(customer_third.id)
    end
  end

  context "when customers have the same values for the ordering criteria" do
    let(:customer_second) do
      create(
        :customer,
        organization:,
        name: "abcde",
        firstname: "Jane",
        lastname: "Smith",
        legal_name: "other name",
        external_id: "22",
        email: "2@example.com",
        created_at: customer_first.created_at
      ).tap do |customer|
        customer.update! id: "00000000-0000-0000-0000-000000000000"
      end
    end

    it "returns a consistent list" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(3)
      expect(returned_ids).to include(customer_first.id)
      expect(returned_ids).to include(customer_second.id)
      expect(returned_ids.index(customer_first.id)).to be > returned_ids.index(customer_second.id)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.customers.count).to eq(1)
      expect(result.customers.current_page).to eq(2)
      expect(result.customers.prev_page).to eq(1)
      expect(result.customers.next_page).to be_nil
      expect(result.customers.total_pages).to eq(2)
      expect(result.customers.total_count).to eq(3)
    end
  end

  context "with search_term" do
    context "when searching for name 'de'" do
      let(:search_term) { "de" }

      it "returns only two customers" do
        expect(returned_ids).to match_array([customer_first.id, customer_second.id])
      end
    end

    context "when searching for firstname 'Jane'" do
      let(:search_term) { "Jane" }

      it "returns only one customer" do
        expect(returned_ids).to eq([customer_second.id])
      end
    end

    context "when searching for lastname 'Johnson'" do
      let(:search_term) { "Johnson" }

      it "returns only one customer" do
        expect(returned_ids).to eq([customer_third.id])
      end
    end

    context "when searching for legalname 'Company'" do
      let(:search_term) { "Company" }

      it "returns only one customer" do
        expect(returned_ids).to eq([customer_third.id])
      end
    end

    context "when searching for external_id '11'" do
      let(:search_term) { "11" }

      it "returns only one customer" do
        expect(returned_ids).to eq([customer_first.id])
      end
    end

    context "when searching for email '1@e'" do
      let(:search_term) { "1@e" }

      it "returns only one customer" do
        expect(returned_ids).to eq([customer_first.id])
      end
    end

    context "when the term matches several customers across different fields" do
      let(:search_term) { "example" }

      it "returns all matching customers without duplicates" do
        expect(returned_ids).to match_array([customer_first.id, customer_second.id, customer_third.id])
      end
    end

    context "when the term matches no customer" do
      let(:search_term) { "nonexistent" }

      it "returns no customer" do
        expect(returned_ids).to be_empty
      end
    end

    context "when the term contains LIKE wildcards" do
      let(:search_term) { "d_fgh" }

      it "matches the wildcards literally" do
        expect(returned_ids).to be_empty
      end
    end

    context "when a matching customer is discarded" do
      let(:search_term) { "defgh" }

      before { customer_first.discard! }

      it "excludes the discarded customer by default" do
        expect(returned_ids).to be_empty
      end

      context "with with_deleted filter" do
        let(:filters) { {with_deleted: true} }

        it "returns the discarded customer" do
          expect(returned_ids).to eq([customer_first.id])
        end
      end
    end
  end

  context "when filtering by countries" do
    let(:filters) { {countries: ["US", "FR"]} }

    it "returns only two customers" do
      expect(returned_ids).to match_array([customer_first.id, customer_second.id])
    end

    context "when filtering by invalid country" do
      let(:filters) { {countries: ["INVALID"]} }

      it "returns no customers" do
        expect(result).not_to be_success
        expect(result.error.messages[:countries]).to match({0 => [/^must be one of: AD, AE.*XK$/]})
      end
    end
  end

  context "when filtering by states" do
    let(:filters) { {states: ["CA", "Paris"]} }

    it "returns only two customers" do
      expect(returned_ids).to match_array([customer_first.id, customer_second.id])
    end

    context "when filtering by invalid state" do
      let(:filters) { {states: "INVALID"} }

      it "returns no customers" do
        expect(result).not_to be_success
        expect(result.error.messages[:states]).to eq(["must be an array"])
      end
    end
  end

  context "when filtering by zipcodes" do
    let(:filters) { {zipcodes: ["10115", "75001"]} }

    it "returns only two customers" do
      expect(returned_ids).to match_array([customer_third.id, customer_second.id])
    end

    context "when filtering by invalid zipcode" do
      let(:filters) { {zipcodes: "INVALID"} }

      it "returns no customers" do
        expect(result).not_to be_success
        expect(result.error.messages[:zipcodes]).to eq(["must be an array"])
      end
    end
  end

  context "when searching for active subscriptions" do
    let(:filters) do
      {active_subscriptions_count_from: from, active_subscriptions_count_to: to}
    end
    let(:subscriptionless_customer) do
      create(:customer, organization:, billing_entity: billing_entity1)
    end

    before do
      subscriptionless_customer
      create(:subscription, customer: customer_first)
      2.times do
        create(:subscription, customer: customer_second)
      end
      3.times do
        create(:subscription, customer: customer_third)
      end
    end

    context "without subscriptions" do
      let(:from) { 0 }
      let(:to) { 0 }

      it "returns customers" do
        expect(returned_ids.count).to eq(1)
        expect(returned_ids).to eq([subscriptionless_customer.id])
      end
    end

    context "with exact subscriptions count" do
      let(:from) { 2 }
      let(:to) { 2 }

      it "returns customers" do
        expect(returned_ids.count).to eq(1)
        expect(returned_ids).to eq([customer_second.id])
      end
    end

    context "with subscriptions count more than a number" do
      let(:from) { 1 }
      let(:to) { nil }

      it "returns customers" do
        expect(returned_ids.count).to eq(2)
        expect(returned_ids).to include(customer_second.id)
        expect(returned_ids).to include(customer_third.id)
      end
    end

    context "with subscriptions count in a range" do
      let(:from) { 1 }
      let(:to) { 2 }

      it "returns customers" do
        expect(returned_ids.count).to eq(2)
        expect(returned_ids).to include(customer_first.id)
        expect(returned_ids).to include(customer_second.id)
      end
    end

    context "with subscriptions count less than a number" do
      let(:from) { nil }
      let(:to) { 2 }

      it "returns customers" do
        expect(returned_ids.count).to eq(2)
        expect(returned_ids).to include(customer_first.id)
        expect(returned_ids).to include(subscriptionless_customer.id)
      end
    end
  end

  context "when filtering by currencies" do
    let(:filters) { {currencies: ["USD"]} }

    it "returns only two customers" do
      expect(returned_ids).to match_array([customer_first.id])
    end

    context "when filtering by invalid currency" do
      let(:filters) { {currencies: ["INVALID"]} }

      it "returns no customers" do
        expect(result).not_to be_success
        expect(result.error.messages[:currencies]).to match({0 => [/^must be one of: AED, AFN.*ZMW$/]})
      end
    end
  end

  context "when filtering by has_tax_identification_number" do
    context "when filtering by true" do
      let(:filters) { {has_tax_identification_number: true} }

      it "returns only the customer with a tax identification number" do
        expect(returned_ids).to match_array([customer_first.id])
      end
    end

    context "when filtering by false" do
      let(:filters) { {has_tax_identification_number: false} }

      it "returns only the customers without a tax identification number" do
        expect(returned_ids).to match_array([customer_second.id, customer_third.id])
      end
    end
  end

  context "when filtering by metadata" do
    context "when filtering by presence" do
      let(:filters) { {metadata: {id: "1"}} }

      it "returns only the customers with the metadata" do
        expect(returned_ids).to match_array([customer_first.id])
      end
    end

    context "when filtering by absence" do
      let(:filters) { {metadata: {name: ""}} }

      it "returns only the customers without the metadata" do
        expect(returned_ids).to match_array([customer_second.id, customer_third.id])
      end
    end

    context "when matching multiple metadata" do
      let(:filters) { {metadata: {id: "1", name: "John Doe"}} }

      it "returns only the customers with the metadata" do
        expect(returned_ids).to match_array([customer_first.id])
      end
    end

    context "when matching one but not the other" do
      let(:filters) { {metadata: {id: "1", name: "Jane Smith"}} }

      it "returns only the customers with the metadata" do
        expect(returned_ids).to be_empty
      end
    end

    context "when filtering by presence and absence" do
      let(:filters) { {metadata: {id: "2", name: ""}} }

      it "returns only the customers with the metadata" do
        expect(returned_ids).to match_array([customer_second.id])
      end
    end
  end

  context "when filters validation fails" do
    let(:filters) { {account_type: %w[random]} }

    it "captures all validation errors" do
      expect(result).not_to be_success
      expect(result.error.messages[:account_type]).to eq({0 => ["must be one of: customer, partner"]})
    end
  end
end
