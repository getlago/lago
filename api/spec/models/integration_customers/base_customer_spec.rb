# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::BaseCustomer do
  subject(:integration_customer) { described_class.new(integration:, customer:, type:, external_customer_id:, organization:) }

  let(:integration) { create(:netsuite_integration) }
  let(:type) { "IntegrationCustomers::NetsuiteCustomer" }
  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }
  let(:external_customer_id) { "123" }

  it { is_expected.to belong_to(:integration) }
  it { is_expected.to belong_to(:customer) }
  it { is_expected.to belong_to(:organization) }

  describe ".accounting_kind" do
    let(:netsuite_customer) { create(:netsuite_customer) }
    let(:xero_customer) { create(:xero_customer) }
    let(:anrok_customer) { create(:anrok_customer) }
    let(:hubspot_customer) { create(:hubspot_customer) }

    before do
      netsuite_customer
      xero_customer
      anrok_customer
      hubspot_customer
    end

    it "returns only accounting kind customers" do
      expect(described_class.accounting_kind).to contain_exactly(netsuite_customer, xero_customer)
    end
  end

  describe ".tax_kind" do
    let(:netsuite_customer) { create(:netsuite_customer) }
    let(:xero_customer) { create(:xero_customer) }
    let(:anrok_customer) { create(:anrok_customer) }
    let(:avalara_customer) { create(:avalara_customer) }

    before do
      netsuite_customer
      xero_customer
      anrok_customer
      avalara_customer
    end

    it "returns only tax kind customers" do
      expect(described_class.tax_kind).to contain_exactly(anrok_customer, avalara_customer)
    end
  end

  describe ".hubspot_kind and .salesforce_kind" do
    let(:netsuite_customer) { create(:netsuite_customer) }
    let(:xero_customer) { create(:xero_customer) }
    let(:anrok_customer) { create(:anrok_customer) }
    let(:hubspot_customer) { create(:hubspot_customer) }
    let(:salesforce_customer) { create(:salesforce_customer) }

    before do
      netsuite_customer
      xero_customer
      anrok_customer
      hubspot_customer
      salesforce_customer
    end

    it "returns only hubspot kind customers" do
      expect(described_class.hubspot_kind).to contain_exactly(hubspot_customer)
    end

    it "returns only salesforce kind customers" do
      expect(described_class.salesforce_kind).to contain_exactly(salesforce_customer)
    end
  end

  describe ".customer_type" do
    subject(:customer_type_call) { described_class.customer_type(type) }

    context "when type is netsuite" do
      let(:type) { "netsuite" }
      let(:customer_type) { "IntegrationCustomers::NetsuiteCustomer" }

      it "returns customer type" do
        expect(subject).to eq(customer_type)
      end
    end

    context "when type is okta" do
      let(:type) { "okta" }
      let(:customer_type) { "IntegrationCustomers::OktaCustomer" }

      it "returns customer type" do
        expect(subject).to eq(customer_type)
      end
    end

    context "when type is anrok" do
      let(:type) { "anrok" }
      let(:customer_type) { "IntegrationCustomers::AnrokCustomer" }

      it "returns customer type" do
        expect(subject).to eq(customer_type)
      end
    end

    context "when type is xero" do
      let(:type) { "xero" }
      let(:customer_type) { "IntegrationCustomers::XeroCustomer" }

      it "returns customer type" do
        expect(subject).to eq(customer_type)
      end
    end

    context "when type is hubspot" do
      let(:type) { "hubspot" }
      let(:customer_type) { "IntegrationCustomers::HubspotCustomer" }

      it "returns customer type" do
        expect(subject).to eq(customer_type)
      end
    end

    context "when type is salesforce" do
      let(:type) { "salesforce" }
      let(:customer_type) { "IntegrationCustomers::SalesforceCustomer" }

      it "returns customer type" do
        expect(subject).to eq(customer_type)
      end
    end

    context "when type is not supported" do
      let(:type) { "n/a" }

      it "raises an error" do
        expect { subject }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "#push_to_settings" do
    it "push the value into settings" do
      integration_customer.push_to_settings(key: "key1", value: "val1")

      expect(integration_customer.settings).to eq(
        {
          "key1" => "val1"
        }
      )
    end
  end

  describe "#get_from_settings" do
    before { integration_customer.push_to_settings(key: "key1", value: "val1") }

    it { expect(integration_customer.get_from_settings("key1")).to eq("val1") }

    it { expect(integration_customer.get_from_settings(nil)).to be_nil }
    it { expect(integration_customer.get_from_settings("foo")).to be_nil }
  end

  describe "#sync_with_provider" do
    it "assigns and retrieve a setting" do
      integration_customer.sync_with_provider = true
      expect(integration_customer.sync_with_provider).to eq(true)
    end
  end

  describe "#tax_kind?" do
    context "with tax integration" do
      let(:integration) { create(:anrok_integration) }
      let(:type) { "IntegrationCustomers::AnrokCustomer" }

      it "returns true" do
        expect(integration_customer).to be_tax_kind
      end
    end

    context "without tax integration" do
      it "returns false" do
        expect(integration_customer).not_to be_tax_kind
      end
    end
  end

  describe "validations" do
    describe "of customer id uniqueness" do
      let(:errors) { another_integration_customer.errors }

      context "when it is unique in scope of type" do
        subject(:another_integration_customer) do
          described_class.new(integration: another_integration, customer:, type:, external_customer_id:)
        end

        let(:another_integration) { create(:netsuite_integration) }

        before { another_integration_customer.valid? }

        it "does not add an error" do
          expect(errors.where(:customer_id, :taken)).not_to be_present
        end
      end

      context "when it is not unique in scope of type" do
        subject(:another_integration_customer) do
          described_class.new(integration:, customer:, type:, external_customer_id:, organization: organization)
        end

        before do
          described_class.create(integration:, customer:, type:, external_customer_id:, organization: organization)
          another_integration_customer.valid?
        end

        it "adds an error" do
          expect(errors.where(:customer_id, :taken)).to be_present
        end
      end
    end

    describe "tax integration uniqueness validation" do
      context "when no tax integration exists for a customer" do
        let(:integration) { create(:anrok_integration) }
        let(:type) { "IntegrationCustomers::AnrokCustomer" }

        it "allows creating a first tax integration" do
          expect(integration_customer).to be_valid
        end
      end

      context "when a tax integration already exists for the customer" do
        let(:integration) { create(:anrok_integration) }
        let(:type) { "IntegrationCustomers::AnrokCustomer" }

        context "with existing anrok integration" do
          before do
            create(:anrok_customer, customer:)
          end

          it "is invalid for a second AnrokCustomer" do
            expect(integration_customer).not_to be_valid
            expect(integration_customer.errors[:type]).to include("tax_integration_exists")
          end
        end

        context "with existing avalara integration" do
          before do
            create(:avalara_customer, customer:)
          end

          it "is invalid for a different tax integration" do
            expect(integration_customer).not_to be_valid
            expect(integration_customer.errors[:type]).to include("tax_integration_exists")
          end
        end

        context "when validating persisted record" do
          before do
            integration_customer.save!
          end

          it "does not add any errors" do
            expect(integration_customer).to be_valid
          end
        end
      end
    end
  end
end
