# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CustomersResolver do
  let(:required_permission) { "customers:view" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity1) { organization.default_billing_entity }
  let(:billing_entity2) { create(:billing_entity, organization:) }
  let(:query) do
    <<~GQL
      query(
        $searchTerm: String,
        $page: Int,
        $limit: Int,
        $accountType: [CustomerAccountTypeEnum!],
        $billingEntityIds: [ID!],
        $activeSubscriptionsCountFrom: Int,
        $activeSubscriptionsCountTo: Int,
        $customerType: CustomerTypeEnum,
        $externalId: String,
        $hasCustomerType: Boolean,
        $hasTaxIdentificationNumber: Boolean,
        $countries: [CountryCode!],
        $states: [String!],
        $zipcodes: [String!],
        $currencies: [CurrencyEnum!],
        $withDeleted: Boolean,
        $metadata: [CustomerMetadataFilter!]
      ) {
        customers(
          limit: $limit,
          searchTerm: $searchTerm,
          page: $page,
          accountType: $accountType,
          billingEntityIds: $billingEntityIds,
          activeSubscriptionsCountFrom: $activeSubscriptionsCountFrom,
          activeSubscriptionsCountTo: $activeSubscriptionsCountTo,
          customerType: $customerType,
          externalId: $externalId,
          hasCustomerType: $hasCustomerType,
          hasTaxIdentificationNumber: $hasTaxIdentificationNumber,
          countries: $countries,
          states: $states,
          zipcodes: $zipcodes,
          currencies: $currencies,
          withDeleted: $withDeleted,
          metadata: $metadata
        ) {
          collection { id externalId name }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  def test_customers_resolver(expected_customers, variables: {})
    variables = {page: 1, limit: 5}.merge(variables)
    result = execute_query(query:, variables: variables)

    customers_response = result["data"]["customers"]

    expected_customers = Array.wrap(expected_customers)

    expect(customers_response["collection"].count).to eq(expected_customers.count)
    expect(customers_response["collection"].pluck("id")).to match_array(expected_customers.pluck(:id))

    expect(customers_response["metadata"]["currentPage"]).to eq(1)
    expect(customers_response["metadata"]["totalCount"]).to eq(expected_customers.count)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "customers:view"

  it "returns a list of customers" do
    customer_1 = create(:customer, organization:)
    customer_2 = create(:customer, organization:)

    test_customers_resolver([customer_1, customer_2])
  end

  context "without current organization" do
    it "returns an error" do
      result = execute_graphql(current_user: membership.user, query:)

      expect_graphql_error(result:, message: "Missing organization id")
    end
  end

  context "when filtering by external id" do
    let(:customer) { create(:customer, organization:) }

    before do
      customer
    end

    it "returns the customer with matching external_id" do
      test_customers_resolver(customer, variables: {externalId: customer.external_id})
    end
  end

  context "when filtering by partner account type" do
    let(:customer) { create(:customer, organization:) }
    let(:partner) { create(:customer, organization:, account_type: "partner") }

    before do
      customer
      partner
    end

    it "returns all customers with account_type partner" do
      test_customers_resolver(partner, variables: {accountType: ["partner"]})
    end
  end

  context "when filtering by billing_entity_id" do
    let(:customer) { create(:customer, organization:, billing_entity: billing_entity1) }
    let(:customer2) { create(:customer, organization:, billing_entity: billing_entity2) }

    before do
      customer
      customer2
    end

    it "returns all customers for the specified billing entity" do
      test_customers_resolver(customer2, variables: {billingEntityIds: [billing_entity2.id]})
    end
  end

  context "when filtering by with_deleted" do
    let(:customer) { create(:customer, organization:) }
    let(:deleted_customer) { create(:customer, organization:, deleted_at: Time.current) }

    before do
      customer
      deleted_customer
    end

    it "returns all customers including deleted ones" do
      test_customers_resolver([customer, deleted_customer], variables: {withDeleted: true})
    end
  end

  context "when filtering by active subscriptions" do
    let(:active_subscription_customer) { create(:customer, organization:) }

    before do
      other_customer = create(:customer, organization:)
      create(:subscription, customer: other_customer)
      2.times do
        create(:subscription, customer: active_subscription_customer)
      end
    end

    it "returns all customers with 2 active subscriptions" do
      test_customers_resolver(active_subscription_customer, variables: {activeSubscriptionsCountFrom: 2, activeSubscriptionsCountTo: 2})
    end
  end

  context "when filtering by customer_type" do
    let!(:company_customer) { create(:customer, organization:, customer_type: "company") }

    before do
      create(:customer, organization:, customer_type: "individual")
    end

    it "returns all customers with customer_type company" do
      test_customers_resolver(company_customer, variables: {customerType: "company"})
    end
  end

  context "when filtering by has_customer_type" do
    let!(:company_customer) { create(:customer, organization:, customer_type: "company") }

    before do
      create(:customer, organization:, customer_type: nil)
    end

    it "returns all customers with customer_type company" do
      test_customers_resolver(company_customer, variables: {hasCustomerType: true})
    end
  end

  context "when filtering by has_tax_identification_number" do
    let!(:customer_with_tax_identification_number) { create(:customer, organization:, tax_identification_number: "1234567890") }

    before do
      create(:customer, organization:, tax_identification_number: nil)
    end

    it "returns all customers with tax_identification_number" do
      test_customers_resolver(customer_with_tax_identification_number, variables: {hasTaxIdentificationNumber: true})
    end
  end

  context "when filtering by countries" do
    let!(:customer_in_france) { create(:customer, organization:, country: "FR") }

    before do
      create(:customer, organization:, country: "US")
    end

    it "returns all customers in France" do
      test_customers_resolver(customer_in_france, variables: {countries: ["FR"]})
    end
  end

  context "when filtering by states" do
    let!(:customer_in_new_york) { create(:customer, organization:, state: "NY") }

    before do
      create(:customer, organization:, state: "CA")
    end

    it "returns all customers in New York" do
      test_customers_resolver(customer_in_new_york, variables: {states: ["NY"]})
    end
  end

  context "when filtering by zipcodes" do
    let!(:customer_in_new_york) { create(:customer, organization:, zipcode: "10001") }

    before do
      create(:customer, organization:, zipcode: "90001")
    end

    it "returns all customers in New York" do
      test_customers_resolver(customer_in_new_york, variables: {zipcodes: ["10001"]})
    end
  end

  context "when filtering by currencies" do
    let!(:customer_in_usd) { create(:customer, organization:, currency: "USD") }

    before do
      create(:customer, organization:, currency: "EUR")
    end

    it "returns all customers in USD" do
      test_customers_resolver(customer_in_usd, variables: {currencies: ["USD"]})
    end
  end

  context "when filtering by search_term" do
    let!(:john_doe) { create(:customer, organization:, name: "John, Doe", email: "john@doe.com", legal_name: "John-Doe", firstname: "Johnnas", lastname: "Doefe", external_id: "1234567890") }

    before do
      create(:customer, organization:, name: "Jane Doe", email: "jane@doe.com", legal_name: "Jane-Doe", firstname: "Janenas", lastname: "Doefae", external_id: "1234567891")
    end

    [
      ["John,", :name],
      ["ohn@doe.com", :email],
      ["hn-d", :legal_name],
      ["nnas", :firstname],
      ["doefe", :lastname],
      ["1234567890", :external_id]
    ].each do |search_term, field|
      context "when search_term matches #{field}" do
        it "returns the matching customer" do
          test_customers_resolver(john_doe, variables: {searchTerm: search_term})
        end
      end
    end
  end

  context "when filtering by metadata" do
    let!(:customer_with_metadata) { create(:customer, organization:) }

    before do
      create(:customer_metadata, customer: customer_with_metadata, key: "key_1", value: "value_1")

      second_customer = create(:customer, organization:)
      create(:customer_metadata, customer: second_customer, key: "key_1", value: "value_1")
      create(:customer_metadata, customer: second_customer, key: "key_2", value: "value_2")
    end

    it "returns all customers with metadata" do
      test_customers_resolver(
        customer_with_metadata,
        variables: {metadata: [{key: "key_1", value: "value_1"}, {key: "key_2", value: ""}]}
      )
    end
  end

  context "with N+1 query detection on associations", bullet: {unused_eager_loading: false} do
    let(:query) do
      <<~GQL
        query(
          $searchTerm: String,
          $page: Int,
          $limit: Int,
          $accountType: [CustomerAccountTypeEnum!],
          $billingEntityIds: [ID!],
          $activeSubscriptionsCountFrom: Int,
          $activeSubscriptionsCountTo: Int,
          $customerType: CustomerTypeEnum,
          $hasCustomerType: Boolean,
          $hasTaxIdentificationNumber: Boolean,
          $countries: [CountryCode!],
          $states: [String!],
          $zipcodes: [String!],
          $currencies: [CurrencyEnum!],
          $withDeleted: Boolean,
          $metadata: [CustomerMetadataFilter!]
        ) {
          customers(
            limit: $limit,
            searchTerm: $searchTerm,
            page: $page,
            accountType: $accountType,
            billingEntityIds: $billingEntityIds,
            activeSubscriptionsCountFrom: $activeSubscriptionsCountFrom,
            activeSubscriptionsCountTo: $activeSubscriptionsCountTo,
            customerType: $customerType,
            hasCustomerType: $hasCustomerType,
            hasTaxIdentificationNumber: $hasTaxIdentificationNumber,
            countries: $countries,
            states: $states,
            zipcodes: $zipcodes,
            currencies: $currencies,
            withDeleted: $withDeleted,
            metadata: $metadata
          ) {
            collection {
              id
              activeSubscriptionsCount
              shippingAddress {
                addressLine1
                addressLine2
                city
                country
                state
                zipcode
              }
              metadata {
                id
                key
                value
                displayInInvoice
              }
              billingEntity {
                id
                code
                name
              }
              netsuiteCustomer {
                id
                integrationId
                externalCustomerId
                integrationCode
                integrationType
                subsidiaryId
                syncWithProvider
              }
              anrokCustomer {
                id
                integrationId
                externalCustomerId
                integrationCode
                integrationType
                syncWithProvider
              }
              avalaraCustomer {
                id
                integrationId
                externalCustomerId
                integrationCode
                integrationType
                syncWithProvider
              }
              xeroCustomer {
                id
                integrationId
                externalCustomerId
                integrationCode
                integrationType
                syncWithProvider
              }
              hubspotCustomer {
                id
                integrationId
                externalCustomerId
                integrationCode
                integrationType
                syncWithProvider
                targetedObject
              }
              salesforceCustomer {
                id
                integrationId
                externalCustomerId
                integrationCode
                integrationType
                syncWithProvider
              }
              providerCustomer {
                id
                providerCustomerId
                syncWithProvider
                providerPaymentMethods
              }
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    before do
      create(:customer, organization:, billing_entity: billing_entity1)
      create(:customer, organization:, billing_entity: billing_entity2)
    end

    it "does not trigger N+1 queries on associations" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect(result["data"]["customers"]["collection"].count).to eq(2)
    end
  end
end
