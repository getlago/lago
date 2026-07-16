# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::CreateService do
  subject(:result) { described_class.call(**create_args) }

  let(:billing_entity) { create(:billing_entity) }
  let(:organization) { billing_entity.organization }
  let(:external_id) { SecureRandom.uuid }

  let(:create_args) do
    {
      organization_id: organization.id,
      external_id:,
      name: "Foo Bar",
      currency: "EUR",
      timezone: "Europe/Paris",
      invoice_grace_period: 2,
      billing_configuration: {
        subscription_invoice_issuing_date_anchor: "current_period_end",
        subscription_invoice_issuing_date_adjustment: "keep_anchor"
      },
      shipping_address: {
        address_line1: "line1",
        address_line2: "line2",
        city: "Paris",
        zipcode: "123456",
        state: "foobar",
        country: "FR"
      }
    }
  end

  before do
    allow(SendWebhookJob).to receive(:perform_later)
    allow(CurrentContext).to receive(:source).and_return("graphql")
  end

  it "creates a new customer" do
    expect(result).to be_success

    customer = result.customer
    expect(customer.id).to be_present
    expect(customer.organization_id).to eq(organization.id)
    expect(customer.billing_entity_id).to eq(billing_entity.id)
    expect(customer.external_id).to eq(create_args[:external_id])
    expect(customer.name).to eq(create_args[:name])
    expect(customer.currency).to eq("EUR")
    expect(customer.timezone).to be_nil
    expect(customer.invoice_grace_period).to be_nil
    expect(customer.subscription_invoice_issuing_date_anchor).to eq("current_period_end")
    expect(customer.subscription_invoice_issuing_date_adjustment).to eq("keep_anchor")
    expect(customer).to be_customer_account
    expect(customer).not_to be_exclude_from_dunning_campaign

    shipping_address = create_args[:shipping_address]
    expect(customer.shipping_address_line1).to eq(shipping_address[:address_line1])
    expect(customer.shipping_address_line2).to eq(shipping_address[:address_line2])
    expect(customer.shipping_city).to eq(shipping_address[:city])
    expect(customer.shipping_zipcode).to eq(shipping_address[:zipcode])
    expect(customer.shipping_state).to eq(shipping_address[:state])
    expect(customer.shipping_country).to eq(shipping_address[:country])
  end

  it "calls SendWebhookJob with customer.created" do
    result

    expect(SendWebhookJob).to have_received(:perform_later).with("customer.created", result.customer)
  end

  it "produces an activity log" do
    result

    expect(Utils::ActivityLog).to have_produced("customer.created").after_commit.with(result.customer)
  end

  context "when organization has multiple billing entities" do
    let(:billing_entity_2) { create(:billing_entity, organization:) }

    before { billing_entity_2 }

    it "creates a customer assigned to the organization's default billing entity" do
      expect(result).to be_success
      expect(result.customer.billing_entity).to be_present
      expect(result.customer.billing_entity).to eq(organization.default_billing_entity)
    end

    context "with billing_entity_code" do
      before do
        create_args.merge!(billing_entity_code: billing_entity_2.code)
      end

      it "creates a new customer" do
        expect(result).to be_success
        expect(result.customer.billing_entity).to eq(billing_entity_2)
      end
    end
  end

  context "when organization has no active billing entity" do
    before do
      organization.billing_entities.update_all(archived_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    it "return a failed result" do
      expect(result).to be_failure
      expect(result.error).to be_a(BaseService::NotFoundFailure)
      expect(result.error.resource).to eq("billing_entity")
    end
  end

  context "when billing_entity_code belongs to an archived billing entity" do
    let(:billing_entity_2) { create(:billing_entity, organization:) }

    before do
      billing_entity_2.update!(archived_at: Time.current)
      create_args.merge!(billing_entity_code: billing_entity_2.code)
    end

    it "return a failed result" do
      expect(result).to be_failure
      expect(result.error).to be_a(BaseService::NotFoundFailure)
      expect(result.error.resource).to eq("billing_entity")
    end
  end

  context "with premium features", :premium do
    let(:create_args) do
      {
        external_id: SecureRandom.uuid,
        name: "Foo Bar",
        firstname: "First",
        lastname: "Last",
        organization_id: organization.id,
        timezone: "Europe/Paris",
        invoice_grace_period: 2
      }
    end

    it "creates a new customer" do
      expect(result).to be_success

      customer = result.customer
      expect(customer.firstname).to eq(create_args[:firstname])
      expect(customer.lastname).to eq(create_args[:lastname])
      expect(customer.customer_type).to be_nil
      expect(customer.timezone).to eq("Europe/Paris")
      expect(customer.invoice_grace_period).to eq(2)
    end

    context "with revenue share feature enabled and account_type 'partner'" do
      let(:organization) do
        create(:organization, premium_integrations: ["revenue_share"])
      end

      before do
        create_args.merge!(account_type: "partner")
      end

      it "creates a customer as partner_account" do
        expect(result).to be_success
        expect(result.customer).to be_partner_account
        expect(result.customer).to be_exclude_from_dunning_campaign
      end
    end
  end

  context "with customer_type" do
    let(:create_args) do
      {
        external_id: SecureRandom.uuid,
        name: "Foo Bar",
        customer_type: "individual",
        organization_id: organization.id
      }
    end

    it "creates customer with customer_type" do
      expect(result).to be_success
      expect(result.customer.customer_type).to eq(create_args[:customer_type])
    end
  end

  context "with metadata" do
    let(:create_args) do
      {
        external_id: SecureRandom.uuid,
        name: "Foo Bar",
        organization_id: organization.id,
        currency: "EUR",
        metadata: [
          {
            key: "manager name",
            value: "John",
            display_in_invoice: true
          },
          {
            key: "manager address",
            value: "Test",
            display_in_invoice: false
          }
        ]
      }
    end

    it "creates customer with metadata" do
      expect(result).to be_success
      expect(result.customer.metadata.count).to eq(2)
    end
  end

  context "when customer already exists" do
    let(:customer) do
      create(:customer, organization:, external_id: create_args[:external_id])
    end

    before { customer }

    it "return a failed result" do
      expect(result).to be_failure
    end
  end

  context "with validation error" do
    let(:create_args) do
      {
        name: "Foo Bar"
      }
    end

    it "return a failed result" do
      expect(result).to be_failure
    end
  end

  context "with stripe payment provider" do
    before do
      create(
        :stripe_provider,
        organization:
      )
    end

    context "with provider customer id" do
      let(:create_args) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          organization_id: organization.id,
          payment_provider: "stripe",
          provider_customer: {provider_customer_id: "cus_12345"}
        }
      end

      it "creates a payment provider customer" do
        expect(result).to be_success
        expect(result.customer.id).to be_present
        expect(result.customer.payment_provider).to eq("stripe")
        expect(result.customer.stripe_customer).to be_present
        expect(result.customer.stripe_customer.provider_customer_id).to eq("cus_12345")
      end
    end
  end

  context "with gocardless payment provider" do
    before do
      create(
        :gocardless_provider,
        organization:
      )
    end

    context "with provider customer id" do
      let(:create_args) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          organization_id: organization.id,
          payment_provider: "gocardless",
          provider_customer: {provider_customer_id: "cus_12345"}
        }
      end

      it "creates a payment provider customer" do
        expect(result).to be_success
        expect(result.customer.id).to be_present
        expect(result.customer.payment_provider).to eq("gocardless")
        expect(result.customer.gocardless_customer).to be_present
        expect(result.customer.gocardless_customer.provider_customer_id).to eq("cus_12345")
      end
    end

    context "with sync option enabled" do
      let(:create_args) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          organization_id: organization.id,
          payment_provider: "gocardless",
          provider_customer: {sync_with_provider: true}
        }
      end

      it "creates a payment provider customer" do
        expect(result).to be_success
        expect(result.customer.id).to be_present
        expect(result.customer.payment_provider).to eq("gocardless")
        expect(result.customer.gocardless_customer).to be_present
      end
    end
  end

  context "with account_type 'partner'" do
    before do
      create_args.merge!(account_type: "partner")
    end

    it "creates a customer as customer_account" do
      expect(result).to be_success
      expect(result.customer).to be_customer_account
      expect(result.customer).not_to be_exclude_from_dunning_campaign
    end
  end

  context "when organization has eu tax management" do
    let(:tax_code) { "lago_eu_fr_standard" }
    let(:eu_tax_result) { Customers::EuAutoTaxesService::Result.new }

    before do
      create(:tax, organization:, code: "lago_eu_fr_standard", rate: 20.0)
      organization.update(eu_tax_management: true)

      eu_tax_result.tax_code = tax_code
      allow(Customers::EuAutoTaxesService).to receive(:call).and_return(eu_tax_result)
    end

    it "assigns the right tax to the customer" do
      expect(result).to be_success

      tax = result.customer.taxes.first
      expect(tax.code).to eq("lago_eu_fr_standard")
    end

    context "when eu tax code is not applicable" do
      let(:eu_tax_result) { Customers::EuAutoTaxesService::Result.new.not_allowed_failure!(code: "") }

      it "does not apply tax" do
        expect(result).to be_success
        expect(result.customer.taxes).to eq([])
      end
    end
  end
end
