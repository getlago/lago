# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::UpsertFromApiService do
  subject(:result) { described_class.call(organization:, params: create_args) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:membership) { create(:membership, organization:) }
  let(:external_id) { SecureRandom.uuid }

  let(:create_args) do
    {
      external_id:,
      name: "Foo Bar",
      currency: "EUR",
      firstname: "First",
      lastname: "Last",
      tax_identification_number: "123456789",
      billing_configuration: {
        document_locale: "fr",
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
    allow(CurrentContext).to receive(:source).and_return("api")
  end

  it "creates a new customer" do
    expect(result).to be_success

    customer = result.customer
    expect(customer.id).to be_present
    expect(customer.organization_id).to eq(organization.id)
    expect(customer.external_id).to eq(create_args[:external_id])
    expect(customer.name).to eq(create_args[:name])
    expect(customer.firstname).to eq(create_args[:firstname])
    expect(customer.lastname).to eq(create_args[:lastname])
    expect(customer.customer_type).to be_nil
    expect(customer.currency).to eq(create_args[:currency])
    expect(customer.tax_identification_number).to eq(create_args[:tax_identification_number])
    expect(customer.timezone).to be_nil
    expect(customer).to be_customer_account
    expect(customer).not_to be_exclude_from_dunning_campaign

    billing = create_args[:billing_configuration]
    expect(customer.document_locale).to eq(billing[:document_locale])
    expect(customer.invoice_grace_period).to be_nil
    expect(result.customer.subscription_invoice_issuing_date_anchor).to eq("current_period_end")
    expect(result.customer.subscription_invoice_issuing_date_adjustment).to eq("keep_anchor")
    expect(customer.skip_invoice_custom_sections).to eq(false)

    shipping_address = create_args[:shipping_address]
    expect(customer.shipping_address_line1).to eq(shipping_address[:address_line1])
    expect(customer.shipping_address_line2).to eq(shipping_address[:address_line2])
    expect(customer.shipping_city).to eq(shipping_address[:city])
    expect(customer.shipping_zipcode).to eq(shipping_address[:zipcode])
    expect(customer.shipping_state).to eq(shipping_address[:state])
    expect(customer.shipping_country).to eq(shipping_address[:country])
  end

  it "creates customer with the default billing entity" do
    expect(result).to be_success
    expect(result.customer.billing_entity).to eq(billing_entity)
  end

  it "creates customer with correctly persisted attributes" do
    expect(result).to be_success

    customer = Customer.find_by(external_id:)
    billing = create_args[:billing_configuration]

    expect(customer).to have_attributes(
      organization_id: organization.id,
      external_id: create_args[:external_id],
      name: create_args[:name],
      currency: create_args[:currency],
      timezone: nil,
      document_locale: billing[:document_locale],
      invoice_grace_period: nil,
      subscription_invoice_issuing_date_anchor: "current_period_end",
      subscription_invoice_issuing_date_adjustment: "keep_anchor"
    )
  end

  it "calls SendWebhookJob with customer.created" do
    customer = result.customer

    expect(SendWebhookJob).to have_received(:perform_later).with("customer.created", customer)
  end

  it "produces an activity log" do
    result = described_class.call(organization:, params: create_args)

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
      let(:create_args) do
        {
          external_id:,
          name: "Foo Bar",
          currency: "EUR",
          billing_entity_code: billing_entity_2.code
        }
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

  context "with account_type 'partner'" do
    before do
      create_args.merge!(account_type: "partner")
    end

    it "creates a customer as customer_account" do
      expect(result).to be_success

      customer = result.customer
      expect(customer).to be_customer_account
      expect(customer).not_to be_exclude_from_dunning_campaign
    end
  end

  context "with email nil" do
    let(:create_args) do
      {
        external_id:,
        email: nil,
        billing_configuration: {
          document_locale: "fr"
        }
      }
    end

    it "creates customer with email nil" do
      expect(result).to be_success
      expect(result.customer.email).to be_nil
    end
  end

  context "with invalid email" do
    let(:create_args) do
      {
        external_id:,
        name: "Foo Bar",
        currency: "EUR",
        email: "@missingusername.com",
        tax_identification_number: "123456789",
        billing_configuration: {
          document_locale: "fr"
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

    it "fails to create customer with wrong email" do
      expect(result).to be_failure
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages.keys).to include(:email)
      expect(result.error.messages[:email]).to include("invalid_email_format")
    end
  end

  context "with email containing unicode lookalike characters" do
    let(:create_args) do
      {
        external_id:,
        name: "Foo Bar",
        email: "hello@something\u2013other.com"
      }
    end

    it "sanitizes the email before saving" do
      expect(result).to be_success
      expect(result.customer.email).to eq("hello@something-other.com")
    end
  end

  context "with external_id already used by a deleted customer" do
    it "creates a customer with the same external_id" do
      create(:customer, :deleted, organization:, external_id:)

      expect { result }.to change(Customer, :count).by(1)

      customers = organization.customers.with_discarded
      expect(customers.count).to eq(2)
      expect(customers.pluck(:external_id).uniq).to eq([external_id])
    end
  end

  context "with an external_id already in use in a not-default billing entity" do
    let(:customer) do
      create(:customer, organization:, billing_entity: billing_entity_2, external_id:)
    end

    let(:billing_entity_2) { create(:billing_entity, organization:) }

    let(:create_args) do
      {
        external_id:,
        name: "Foo Bar",
        currency: "EUR",
        billing_entity_code: billing_entity.code
      }
    end

    before { customer }

    it "updates the billing_entity of the customer" do
      expect(result).to be_success
      expect(result.customer).to eq(customer)
      expect(result.customer.billing_entity).to eq(billing_entity)
    end

    context "when the customer already has an invoice" do
      before do
        create(:invoice, customer: customer)
      end

      it "does not update the billing_entity of the customer" do
        expect(result).to be_success
        expect(result.customer).to eq(customer)
        expect(result.customer.billing_entity).to eq(billing_entity_2)
      end

      context "when multi_entity_billing feature flag is enabled" do
        before { organization.enable_feature_flag!(:multi_entity_billing) }

        it "updates the billing_entity of the customer" do
          expect(result).to be_success
          expect(result.customer).to eq(customer)
          expect(result.customer.billing_entity).to eq(billing_entity)
        end
      end
    end

    context "when not sending billing_entity_code" do
      let(:create_args) do
        {
          external_id:,
          name: "Updated name"
        }
      end

      it "does not update the billing_entity of the customer" do
        expect(result).to be_success
        expect(result.customer).to eq(customer)
        expect(result.customer.billing_entity).to eq(billing_entity_2)
      end
    end
  end

  context "when the billing entity changes and entities have different EU tax settings" do
    let(:eu_billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: true) }
    let(:other_eu_billing_entity) { create(:billing_entity, organization:, country: "DE", eu_tax_management: true) }
    let(:non_eu_billing_entity) { create(:billing_entity, organization:, country: "US", eu_tax_management: false) }

    let(:fr_tax) { create(:tax, organization:, code: "lago_eu_fr_standard", rate: 20.0) }
    let(:de_tax) { create(:tax, organization:, code: "lago_eu_de_standard", rate: 19.0) }

    let(:customer) do
      create(:customer, organization:, external_id:, billing_entity: source_billing_entity, country: nil, zipcode: nil, tax_identification_number: nil)
    end

    let(:create_args) { {external_id:, billing_entity_code: target_billing_entity.code} }

    before do
      fr_tax
      de_tax
      customer
      create(:customer_applied_tax, organization:, customer:, tax: applied_tax) if applied_tax
    end

    context "when moving from an EU entity to a non-EU entity" do
      let(:source_billing_entity) { eu_billing_entity }
      let(:target_billing_entity) { non_eu_billing_entity }
      let(:applied_tax) { fr_tax }

      it "resets the EU tax so the customer falls back to the billing entity" do
        expect(result).to be_success
        expect(result.customer.billing_entity).to eq(non_eu_billing_entity)
        expect(result.customer.taxes).to eq([])
      end
    end

    context "when moving from a non-EU entity to an EU entity" do
      let(:source_billing_entity) { non_eu_billing_entity }
      let(:target_billing_entity) { eu_billing_entity }
      let(:applied_tax) { nil }

      it "assigns the new billing entity EU tax" do
        expect(result).to be_success
        expect(result.customer.billing_entity).to eq(eu_billing_entity)
        expect(result.customer.taxes.pluck(:code)).to eq(["lago_eu_fr_standard"])
      end
    end

    context "when moving between two EU entities in different countries" do
      let(:source_billing_entity) { eu_billing_entity }
      let(:target_billing_entity) { other_eu_billing_entity }
      let(:applied_tax) { fr_tax }

      it "re-evaluates the EU tax against the new billing entity" do
        expect(result).to be_success
        expect(result.customer.billing_entity).to eq(other_eu_billing_entity)
        expect(result.customer.taxes.pluck(:code)).to eq(["lago_eu_de_standard"])
      end
    end

    context "when the new EU entity requires a VIES check" do
      let(:source_billing_entity) { eu_billing_entity }
      let(:target_billing_entity) { other_eu_billing_entity }
      let(:applied_tax) { fr_tax }

      let(:customer) do
        create(:customer, organization:, external_id:, billing_entity: source_billing_entity, country: nil, zipcode: nil, tax_identification_number: "FR123456789")
      end

      it "resets the EU tax and schedules a VIES check for the new billing entity" do
        expect(result).to be_success
        expect(result.customer.taxes).to eq([])
        expect(result.customer.pending_vies_check).to have_attributes(
          billing_entity: other_eu_billing_entity,
          tax_identification_number: "FR123456789"
        )
      end
    end

    context "when the billing entity does not change" do
      let(:source_billing_entity) { eu_billing_entity }
      let(:target_billing_entity) { eu_billing_entity }
      let(:applied_tax) { fr_tax }

      it "keeps the existing customer tax" do
        expect(result).to be_success
        expect(result.customer.taxes.pluck(:code)).to eq(["lago_eu_fr_standard"])
      end
    end
  end

  context "with customer_type" do
    let(:create_args) do
      {
        external_id:,
        name: "Foo Bar",
        currency: "EUR",
        customer_type: "company"
      }
    end

    it "creates customer with correct customer_type" do
      expect(result).to be_success

      expect(result.customer.customer_type).to eq(create_args[:customer_type])
    end

    context "with invalid customer_type" do
      let(:create_args) do
        {
          external_id:,
          name: "Foo Bar",
          currency: "EUR",
          customer_type: "default_type"
        }
      end

      it "fails to create customer" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:customer_type)
        expect(result.error.messages[:customer_type]).to include("value_is_invalid")
      end
    end
  end

  context "with metadata" do
    let(:create_args) do
      {
        external_id:,
        name: "Foo Bar",
        currency: "EUR",
        billing_configuration: {
          document_locale: "fr"
        },
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

  context "with finalize_zero_amount_invoice" do
    let(:create_args) do
      {
        external_id:,
        finalize_zero_amount_invoice: "skip"
      }
    end

    it "creates customer with finalize_zero_amount_invoice" do
      expect(result).to be_success
      expect(result.customer.finalize_zero_amount_invoice).to eq("skip")
    end

    context "with nil value for finalize_zero_amount_invoice" do
      let(:create_args) do
        {
          external_id:,
          finalize_zero_amount_invoice: nil
        }
      end

      it "creates customer with finalize_zero_amount_invoice set to the default value" do
        expect(result).to be_success
        expect(result.customer.finalize_zero_amount_invoice).to eq("inherit")
      end
    end

    context "with incorrect value of finalize_zero_amount_invoice" do
      let(:create_args) do
        {
          external_id:,
          finalize_zero_amount_invoice: "bad value"
        }
      end

      it "fails with validation error" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:finalize_zero_amount_invoice)
        expect(result.error.messages[:finalize_zero_amount_invoice]).to include("invalid_value")
      end
    end
  end

  context "with premium features", :premium do
    let(:create_args) do
      {
        external_id:,
        name: "Foo Bar",
        timezone: "Europe/Paris",
        billing_configuration: {
          invoice_grace_period: 3
        }
      }
    end

    it "creates a new customer" do
      expect(result).to be_success
      expect(result.customer.timezone).to eq(create_args[:timezone])
      expect(result.customer.invoice_grace_period).to eq(3)
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

      context "when updating a customer that already have an invoice" do
        let(:customer) do
          create(:customer, organization:, account_type: "customer", external_id:)
        end

        let(:invoice) { create(:invoice, customer: customer) }

        before { invoice }

        it "doesn't update customer to partner" do
          expect(result).to be_success
          expect(result.customer).to be_customer_account
        end
      end

      context "with invalid account_type" do
        before { create_args.merge!(account_type: "invalid") }

        it "fails to create customer" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages.keys).to include(:account_type)
          expect(result.error.messages[:account_type]).to include("value_is_invalid")
        end
      end
    end
  end

  context "with invoice_custom_sections params" do
    let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }
    let(:create_args) do
      {
        external_id:,
        name: "Foo Bar",
        currency: "EUR",
        firstname: "First",
        lastname: "Last",
        invoice_custom_section_codes: [invoice_custom_section.code]
      }
    end

    it "creates customer with invoice_custom_sections" do
      expect(result).to be_success

      customer = result.customer
      expect(customer.selected_invoice_custom_sections.count).to eq(1)
      expect(customer.selected_invoice_custom_sections.first).to eq(invoice_custom_section)
      expect(customer.skip_invoice_custom_sections).to eq(false)
    end
  end

  context "when customer already exists" do
    let(:customer) do
      create(
        :customer,
        organization:,
        external_id:,
        email: "foo@bar.com"
      )
    end

    before { customer }

    it "updates the customer" do
      expect(result).to be_success
      expect(result.customer).to eq(customer)
      expect(result.customer.name).to eq(create_args[:name])
      expect(result.customer.external_id).to eq(create_args[:external_id])

      # NOTE: It should not erase exsting properties
      expect(result.customer.country).to eq(customer.country)
      expect(result.customer.address_line1).to eq(customer.address_line1)
      expect(result.customer.address_line2).to eq(customer.address_line2)
      expect(result.customer.state).to eq(customer.state)
      expect(result.customer.zipcode).to eq(customer.zipcode)
      expect(result.customer.email).to eq(customer.email)
      expect(result.customer.city).to eq(customer.city)
      expect(result.customer.url).to eq(customer.url)
      expect(result.customer.phone).to eq(customer.phone)
      expect(result.customer.logo_url).to eq(customer.logo_url)
      expect(result.customer.legal_name).to eq(customer.legal_name)
      expect(result.customer.legal_number).to eq(customer.legal_number)
    end

    it "calls SendWebhookJob with customer.updated" do
      result

      expect(SendWebhookJob).to have_received(:perform_later).with("customer.updated", customer)
    end

    it "produces an activity log" do
      result = described_class.call(organization:, params: create_args)

      expect(Utils::ActivityLog).to have_produced("customer.updated").after_commit.with(result.customer)
    end

    context "with provider customer" do
      let(:payment_provider) { create(:stripe_provider, organization:) }
      let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider:) }
      let(:stripe_customer_result) { BaseService::Result.new }

      before do
        allow(Stripe::Customer).to receive(:update).and_return(stripe_customer_result)
        stripe_customer
        customer.update!(payment_provider: "stripe")
      end

      it "updates the customer" do
        expect(result).to be_success
        expect(result.customer).to eq(customer)
        expect(result.customer.name).to eq(create_args[:name])
        expect(result.customer.external_id).to eq(create_args[:external_id])
        expect(result.customer.document_locale).to eq(create_args[:billing_configuration][:document_locale])
      end
    end

    context "with metadata" do
      let(:customer_metadata) { create(:customer_metadata, customer:) }
      let(:another_customer_metadata) { create(:customer_metadata, customer:, key: "test", value: "1") }
      let(:create_args) do
        {
          external_id:,
          name: "Foo Bar",
          currency: "EUR",
          billing_configuration: {
            document_locale: "fr"
          },
          metadata: [
            {
              id: customer_metadata.id,
              key: "new key",
              value: "new value",
              display_in_invoice: true
            },
            {
              key: "Added key",
              value: "Added value",
              display_in_invoice: true
            }
          ]
        }
      end

      before do
        customer_metadata
        another_customer_metadata
      end

      it "updates metadata" do
        metadata_keys = result.customer.metadata.pluck(:key)
        metadata_ids = result.customer.metadata.pluck(:id)

        expect(result.customer.metadata.count).to eq(2)
        expect(metadata_keys).to eq(["new key", "Added key"])
        expect(metadata_ids).to include(customer_metadata.id)
        expect(metadata_ids).not_to include(another_customer_metadata.id)
      end

      context "when more than five metadata objects are provided" do
        let(:create_args) do
          {
            external_id:,
            name: "Foo Bar",
            currency: "EUR",
            billing_configuration: {
              document_locale: "fr"
            },
            metadata: [
              {
                id: customer_metadata.id,
                key: "new key",
                value: "new value",
                display_in_invoice: true
              },
              {
                key: "Added key1",
                value: "Added value1",
                display_in_invoice: true
              },
              {
                key: "Added key2",
                value: "Added value2",
                display_in_invoice: true
              },
              {
                key: "Added key3",
                value: "Added value3",
                display_in_invoice: true
              },
              {
                key: "Added key4",
                value: "Added value4",
                display_in_invoice: true
              },
              {
                key: "Added key5",
                value: "Added value5",
                display_in_invoice: true
              }
            ]
          }
        end

        it "fails to create customer with metadata" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages.keys).to include(:metadata)
          expect(result.error.messages[:metadata]).to include("invalid_count")
        end
      end
    end

    context "with integration customers" do
      let(:create_args) do
        {
          external_id:,
          name: "Foo Bar",
          currency: "EUR",
          billing_configuration: {
            document_locale: "fr"
          },
          integration_customers:
        }
      end

      context "when there are netusite and anrok customer sent" do
        let(:integration_customers) do
          [
            {
              external_customer_id: "12345",
              integration_type: "netsuite",
              integration_code: "code1",
              subsidiary_id: "1",
              sync_with_provider: true
            },
            {
              external_customer_id: "65432",
              integration_type: "anrok",
              integration_code: "code3",
              sync_with_provider: true
            }
          ]
        end

        it "creates customer with integration customers" do
          expect(result).to be_success
          expect(result.customer).to be_persisted
          # FIXME: should we test the integration customers?
        end
      end

      context "when there are multiple integration customers of the same type" do
        let(:integration_customers) do
          [
            {
              external_customer_id: "12345",
              integration_type: "netsuite",
              integration_code: "code1",
              subsidiary_id: "1",
              sync_with_provider: true
            },
            {
              external_customer_id: "02346",
              integration_type: "netsuite",
              integration_code: "code2",
              subsidiary_id: "1",
              sync_with_provider: true
            },
            {
              external_customer_id: "65432",
              integration_type: "anrok",
              integration_code: "code3",
              sync_with_provider: true
            }
          ]
        end

        it "fails to create customer with integration customers" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages.keys).to include(:integration_customers)
          expect(result.error.messages[:integration_customers]).to include("invalid_count_per_integration_type")
        end
      end
    end

    context "when attached to a subscription" do
      let(:create_args) do
        {
          external_id:,
          name: "Foo Bar",
          currency: "CAD"
        }
      end

      before do
        subscription = create(:subscription, customer:)
        customer.update!(currency: subscription.plan.amount_currency)
      end

      it "fails is we change the subscription" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:currency)
        expect(result.error.messages[:currency]).to include("currencies_does_not_match")
      end
    end

    context "when updating invoice grace period", :premium do
      let(:create_args) do
        {
          external_id:,
          billing_configuration: {invoice_grace_period: 2}
        }
      end

      before do
        allow(Customers::UpdateInvoiceIssuingDateSettingsService).to receive(:call).and_call_original
      end

      it "calls UpdateInvoiceIssuingDateSettingsService" do
        result

        expect(Customers::UpdateInvoiceIssuingDateSettingsService).to have_received(:call).with(customer:, params: create_args)
      end
    end

    context "when updating email to nil" do
      let(:create_args) do
        {
          external_id:,
          email: nil
        }
      end

      it "updates customer to not have email" do
        expect(result).to be_success
        expect(result.customer.email).to be_nil
      end
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

  context "with stripe configuration" do
    let(:create_args) do
      {
        external_id: SecureRandom.uuid,
        name: "Foo Bar",
        billing_configuration: {
          payment_provider: "stripe",
          payment_provider_code: "stripe_1",
          provider_customer_id: "stripe_id"
        }
      }
    end

    context "when payment provider does not exist" do
      let(:error_messages) { {base: ["payment_provider_not_found"]} }

      it "fails to create customer" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq(error_messages)
      end
    end

    context "when payment provider exists" do
      before { create(:stripe_provider, organization:, code: "stripe_1") }

      it "creates a stripe customer" do
        expect(result).to be_success
        expect(result.customer.id).to be_present
        expect(result.customer.payment_provider).to eq("stripe")
        expect(result.customer.stripe_customer).to be_present
        expect(result.customer.stripe_customer.id).to be_present
        expect(result.customer.stripe_customer.provider_customer_id).to eq("stripe_id")
      end
    end

    context "when customer already exists" do
      let(:payment_provider) { "stripe" }
      let(:payment_provider_code) { "stripe_1" }
      let(:create_args) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          billing_configuration: {
            payment_provider:,
            payment_provider_code:,
            provider_customer_id: "stripe_id"
          }
        }
      end
      let(:customer) do
        create(
          :customer,
          organization:,
          billing_entity:,
          external_id: create_args[:external_id],
          email: "foo@bar.com",
          payment_provider_code: nil,
          payment_provider: nil
        )
      end

      before { customer }

      context "when payment provider exists" do
        let(:stripe_provider) { create(:stripe_provider, code: payment_provider_code, organization:) }

        before { stripe_provider }

        it "updates the customer" do
          expect(result).to be_success
          expect(result.customer).to eq(customer)

          # NOTE: It should not erase exsting properties
          expect(result.customer.payment_provider).to eq("stripe")
          expect(result.customer.stripe_customer).to be_present
          expect(result.customer.stripe_customer.id).to be_present
          expect(result.customer.stripe_customer.provider_customer_id).to eq("stripe_id")
        end
      end

      context "when payment provider does not exists" do
        it "fails" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:base]).to include("payment_provider_not_found")
        end
      end

      context "when payment_provider is invalid" do
        let(:payment_provider) { "foo" }

        it "fails" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:base]).to include("payment_provider_not_found")
        end
      end

      context "when payment_provider is not sent" do
        let(:create_args) do
          {
            external_id: SecureRandom.uuid,
            name: "Foo Bar",
            billing_configuration: {
              sync_with_provider: true
            }
          }
        end

        it "updates the customer and reset payment_provider attribute" do
          expect(result).to be_success
          expect(result.customer).to eq(customer)

          # NOTE: It should not erase existing properties
          expect(result.customer.payment_provider).to eq(nil)
          expect(result.customer.stripe_customer).not_to be_present
        end
      end

      context "when removing the payment provider" do
        let(:stripe_provider) { create(:stripe_provider, organization:, code: "stripe_1") }
        let(:external_id) { SecureRandom.uuid }
        let(:customer) do
          create(
            :customer,
            organization:,
            external_id:,
            payment_provider: "stripe",
            payment_provider_code: "stripe_1"
          )
        end
        let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider: stripe_provider) }
        let(:payment_method) { create(:payment_method, customer:, payment_provider_customer: stripe_customer) }
        let(:create_args) do
          {
            external_id:,
            billing_configuration: {
              payment_provider: nil
            }
          }
        end

        before { payment_method }

        it "removes the payment provider from customer" do
          expect(result).to be_success

          expect(result.customer.payment_provider).to be_nil
        end

        it "does not discard the provider customer" do
          expect(result).to be_success

          expect(stripe_customer.reload).not_to be_discarded
        end

        it "discards the old provider customer's payment methods" do
          expect(result).to be_success

          expect(payment_method.reload).to be_discarded
        end
      end

      context "when switching from stripe to gocardless" do
        let(:stripe_provider) { create(:stripe_provider, organization:, code: "stripe_1") }
        let(:external_id) { SecureRandom.uuid }
        let(:customer) do
          create(
            :customer,
            organization:,
            external_id:,
            payment_provider: "stripe",
            payment_provider_code: "stripe_1"
          )
        end
        let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider: stripe_provider) }
        let(:payment_method) { create(:payment_method, customer:, payment_provider_customer: stripe_customer) }

        before do
          payment_method
          create(:gocardless_provider, organization:, code: "gocardless_1")
        end

        context "when provider_customer_id is sent" do
          let(:create_args) do
            {
              external_id:,
              billing_configuration: {
                payment_provider: "gocardless",
                payment_provider_code: "gocardless_1",
                provider_customer_id: "gocardless_id"
              }
            }
          end

          it "creates the gocardless provider customer" do
            expect(result).to be_success

            expect(result.customer.payment_provider).to eq("gocardless")
            expect(result.customer.payment_provider_code).to eq("gocardless_1")
            expect(result.customer.provider_customer.provider_customer_id).to eq("gocardless_id")
          end

          it "does not discard the provider customer" do
            expect(result).to be_success

            expect(stripe_customer.reload).not_to be_discarded
          end

          it "discards the old provider customer's payment methods" do
            expect(result).to be_success

            expect(payment_method.reload).to be_discarded
          end
        end

        context "when provider_customer_id is not sent" do
          let(:create_args) do
            {
              external_id:,
              billing_configuration: {
                sync_with_provider: true,
                payment_provider: "gocardless",
                payment_provider_code: "gocardless_1"
              }
            }
          end

          # NOTE: This describes a scenario with incorrect behavior that currently exists.
          #       The new provider customer does not get created and the previous one is not discarded
          it "does not create the gocardless provider customer" do
            expect(result).to be_success

            expect(result.customer.payment_provider).to eq("gocardless")
            expect(result.customer.payment_provider_code).to eq("gocardless_1")
            expect(result.customer.provider_customer).to be_nil
          end

          it "does not discard the provider customer" do
            expect(result).to be_success

            expect(stripe_customer.reload).not_to be_discarded
          end

          it "does not discard the old provider customer's payment methods" do
            expect(result).to be_success

            expect(payment_method.reload).not_to be_discarded
          end
        end
      end

      context "when changing the connected stripe account" do
        let(:old_stripe_provider) { create(:stripe_provider, organization:, code: "stripe_1") }
        let(:new_stripe_provider) { create(:stripe_provider, organization:, code: "stripe_2") }
        let(:external_id) { SecureRandom.uuid }
        let(:customer) do
          create(
            :customer,
            organization:,
            external_id:,
            payment_provider: "stripe",
            payment_provider_code: "stripe_1"
          )
        end
        let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider: old_stripe_provider) }
        let(:payment_method) do
          create(
            :payment_method,
            customer:,
            payment_provider_customer: stripe_customer,
            payment_provider: old_stripe_provider
          )
        end

        before do
          payment_method
          new_stripe_provider
        end

        context "when provider_customer_id is sent" do
          let(:create_args) do
            {
              external_id:,
              billing_configuration: {
                payment_provider: "stripe",
                payment_provider_code: "stripe_2",
                provider_customer_id: "stripe_2_id"
              }
            }
          end

          # NOTE: This assumes that the provider_customer_id exists on stripe
          #       and the update is performed succesfully
          before do
            allow(Stripe::Customer).to receive(:update).and_return(BaseService::Result.new)
          end

          it "updates the stripe provider_code and provider_customer_id" do
            expect(result).to be_success

            expect(result.customer.payment_provider).to eq("stripe")
            expect(result.customer.payment_provider_code).to eq("stripe_2")
            expect(result.customer.provider_customer.provider_customer_id).to eq("stripe_2_id")
          end

          it "does not discard the provider customer" do
            expect(result).to be_success

            expect(stripe_customer.reload).not_to be_discarded
          end

          it "discards the old payment methods" do
            expect(result).to be_success

            expect(payment_method.reload).to be_discarded
          end
        end

        # NOTE: This is a scenario with incorrect behavior that currently exists.
        #       The old customer ID doesn't exist on the new Stripe account, causing an error
        #       when trying to update the customer on Stripe.
        context "when provider_customer_id is not sent" do
          let(:create_args) do
            {
              external_id:,
              billing_configuration: {
                sync_with_provider: true,
                payment_provider: "stripe",
                payment_provider_code: "stripe_2"
              }
            }
          end

          before do
            allow(Stripe::Customer).to receive(:update).and_raise(
              Stripe::InvalidRequestError.new(
                "No such customer: '#{stripe_customer.provider_customer_id}'",
                "id",
                http_status: 404,
                code: "resource_missing"
              )
            )
          end

          it "fails with a third party error" do
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::ThirdPartyFailure)
            expect(result.error.error_code).to include("resource_missing")
          end
        end

        context "when provider_customer_id is set to nil" do
          let(:create_args) do
            {
              external_id:,
              billing_configuration: {
                provider_customer_id: nil,
                payment_provider: "stripe",
                payment_provider_code: "stripe_2"
              }
            }
          end

          # NOTE: This bypasses an issue with the check:
          #
          #       if customer.provider_customer&.provider_customer_id
          #         PaymentProviderCustomers::UpdateService.call(customer)
          #       end
          #
          #       Since customer is not reloaded, it still checks the previous provider_customer state,
          #       which has a provider_customer_id
          before do
            allow(Stripe::Customer).to receive(:update).and_return(BaseService::Result.new)
          end

          it "updates the stripe provider code" do
            expect(result).to be_success

            expect(result.customer.payment_provider).to eq("stripe")
            expect(result.customer.payment_provider_code).to eq("stripe_2")
            expect(result.customer.provider_customer.provider_customer_id).to be_nil
          end

          it "does not discard the provider customer" do
            expect(result).to be_success

            expect(stripe_customer.reload).not_to be_discarded
          end

          it "discards the old payment methods" do
            expect(result).to be_success

            expect(payment_method.reload).to be_discarded
          end
        end
      end
    end
  end

  context "with gocardless configuration" do
    let(:create_args) do
      {
        external_id: SecureRandom.uuid,
        name: "Foo Bar",
        billing_configuration: {
          payment_provider: "gocardless",
          provider_customer_id: "gocardless_id"
        }
      }
    end

    context "when payment provider does not exist" do
      let(:error_messages) { {base: ["payment_provider_not_found"]} }

      it "fails to create customer" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq(error_messages)
      end
    end

    context "when payment provider exists" do
      before { create(:gocardless_provider, organization:, code: "gocardless_1") }

      it "creates a gocardless customer" do
        expect(result).to be_success
        expect(result.customer.id).to be_present
        expect(result.customer.payment_provider).to eq("gocardless")
        expect(result.customer.gocardless_customer).to be_present
        expect(result.customer.gocardless_customer.id).to be_present
        expect(result.customer.gocardless_customer.provider_customer_id).to eq("gocardless_id")
      end
    end
  end

  context "with unknown payment provider" do
    let(:create_args) do
      {
        external_id: SecureRandom.uuid,
        name: "Foo Bar",
        billing_configuration: {
          payment_provider: "foo"
        }
      }
    end

    it "does not create a payment provider customer" do
      expect(result).to be_success
      expect(result.customer.id).to be_present
      expect(result.customer.payment_provider).to be_nil
      expect(result.customer.stripe_customer).to be_nil
      expect(result.customer.gocardless_customer).to be_nil
    end
  end

  context "when billing configuration is not provided" do
    it "does not creates a payment provider customer" do
      expect(result).to be_success
      expect(result.customer.id).to be_present
      expect(result.customer.payment_provider).to be_nil
      expect(result.customer.stripe_customer).not_to be_present
      expect(result.customer.gocardless_customer).not_to be_present
    end

    context "when customer is updated" do
      before do
        create(
          :customer,
          organization:,
          billing_entity:,
          external_id: create_args[:external_id],
          payment_provider: nil,
          payment_provider_code: nil,
          email: "foo@bar.com"
        )
      end

      it "does not create a payment provider customer" do
        expect(result).to be_success
        expect(result.customer.id).to be_present
        expect(result.customer.payment_provider).to be_nil
        expect(result.customer.stripe_customer).not_to be_present
        expect(result.customer.gocardless_customer).not_to be_present
      end
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
      expect(tax.code).to eq(tax_code)
    end

    context "when eu tax code is not applicable" do
      let(:eu_tax_result) { Customers::EuAutoTaxesService::Result.new.not_allowed_failure!(code: "") }

      it "does not apply tax" do
        expect(result).to be_success
        expect(result.customer.taxes).to eq([])
      end
    end
  end

  context "with tax_codes" do
    let(:create_args) do
      {
        external_id: SecureRandom.uuid,
        name: "Foo Bar",
        organization_id: organization.id
      }
    end

    it "creates customer with tax_codes" do
      create_args[:tax_codes] = ["123456789"]
      create(:tax, organization:, code: "123456789")

      expect(result).to be_success
      expect(result.customer.taxes.count).to eq(1)
      expect(result.customer.taxes.first.code).to eq("123456789")
    end

    it "updates customer with tax_codes" do
      create_args[:tax_codes] = []
      tax = create(:tax, organization:, code: "987654321")
      customer = create(:customer, organization:, external_id: create_args[:external_id])
      create(:customer_applied_tax, customer:, tax:)

      expect(result).to be_success
      expect(result.customer.taxes.count).to eq(0)
    end
  end

  context "with error details" do
    let(:customer) do
      create(:customer, organization:, external_id:, address_line1: "Old Address")
    end

    before do
      create(:error_detail, owner: customer, organization:, error_code: :tax_error)
    end

    context "when address fields change" do
      before { create_args[:address_line1] = "New Address" }

      it "discards tax_error error_details" do
        expect(result).to be_success
        expect(customer.error_details.count).to be_zero
      end
    end

    context "when non-address fields change" do
      let(:customer) do
        create(
          :customer,
          organization:, external_id:,
          shipping_address_line1: create_args.dig(:shipping_address, :address_line1),
          shipping_address_line2: create_args.dig(:shipping_address, :address_line2),
          shipping_city: create_args.dig(:shipping_address, :city),
          shipping_zipcode: create_args.dig(:shipping_address, :zipcode),
          shipping_state: create_args.dig(:shipping_address, :state),
          shipping_country: create_args.dig(:shipping_address, :country)&.upcase
        )
      end

      before { create_args[:name] = "New Name" }

      it "does not discard tax_error error_details" do
        expect(result).to be_success
        expect(customer.error_details.count).to eq(1)
      end
    end
  end
end
