# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::CustomersController do
  describe "POST /api/v1/customers" do
    subject { post_with_token(organization, "/api/v1/customers", {customer: create_params}) }

    let(:organization) { stripe_provider.organization }
    let(:stripe_provider) { create(:stripe_provider) }
    let(:create_params) do
      {
        external_id: SecureRandom.uuid,
        name: "Foo Bar Inc.",
        firstname: "Foo",
        lastname: "Bar",
        customer_type: "company",
        currency: "EUR",
        timezone: "America/New_York",
        external_salesforce_id: "foobar"
      }
    end

    include_examples "requires API permission", "customer", "write"

    it "returns a success" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:customer][:lago_id]).to be_present
      expect(json[:customer][:external_id]).to eq(create_params[:external_id])
      expect(json[:customer][:name]).to eq(create_params[:name])
      expect(json[:customer][:firstname]).to eq(create_params[:firstname])
      expect(json[:customer][:lastname]).to eq(create_params[:lastname])
      expect(json[:customer][:customer_type]).to eq(create_params[:customer_type])
      expect(json[:customer][:created_at]).to be_present
      expect(json[:customer][:currency]).to eq(create_params[:currency])
      expect(json[:customer][:external_salesforce_id]).to eq(create_params[:external_salesforce_id])
      expect(json[:customer][:account_type]).to eq("customer")
      expect(json[:customer][:billing_entity_code]).to eq(organization.default_billing_entity.code)
    end

    context "with premium features", :premium do
      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          timezone: "America/New_York"
        }
      end

      it "returns a success" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:customer][:timezone]).to eq(create_params[:timezone])
      end
    end

    context "with finalize_zero_amount_invoice" do
      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          finalize_zero_amount_invoice: "skip"
        }
      end

      it "returns a success" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:customer][:finalize_zero_amount_invoice]).to eq("skip")
      end
    end

    context "with billing configuration", :premium do
      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          billing_configuration: {
            invoice_grace_period: 3,
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "keep_anchor",
            payment_provider: "stripe",
            payment_provider_code: stripe_provider.code,
            provider_customer_id: "stripe_id",
            document_locale: "fr",
            provider_payment_methods:
          }
        }
      end

      before do
        stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
          .to_return(status: 200, body: body.to_json, headers: {})

        allow(::Stripe::Checkout::Session).to receive(:create)
          .and_return({"url" => "https://example.com"})

        subject
      end

      context "when provider payment methods are not present" do
        let(:provider_payment_methods) { nil }

        it "returns a success" do
          expect(response).to have_http_status(:success)

          expect(json[:customer][:lago_id]).to be_present
          expect(json[:customer][:external_id]).to eq(create_params[:external_id])

          billing = json[:customer][:billing_configuration]

          expect(billing).to be_present
          expect(billing[:payment_provider]).to eq("stripe")
          expect(billing[:payment_provider_code]).to eq(stripe_provider.code)
          expect(billing[:provider_customer_id]).to eq("stripe_id")
          expect(billing[:invoice_grace_period]).to eq(3)
          expect(billing[:subscription_invoice_issuing_date_anchor]).to eq("current_period_end")
          expect(billing[:subscription_invoice_issuing_date_adjustment]).to eq("keep_anchor")
          expect(billing[:document_locale]).to eq("fr")
          expect(billing[:provider_payment_methods]).to eq(%w[card])
        end
      end

      context "when both provider payment methods are set" do
        let(:provider_payment_methods) { %w[card sepa_debit] }

        it "returns a success" do
          expect(response).to have_http_status(:success)

          expect(json[:customer][:lago_id]).to be_present
          expect(json[:customer][:external_id]).to eq(create_params[:external_id])

          billing = json[:customer][:billing_configuration]

          expect(billing).to be_present
          expect(billing[:payment_provider]).to eq("stripe")
          expect(billing[:payment_provider_code]).to eq(stripe_provider.code)
          expect(billing[:provider_customer_id]).to eq("stripe_id")
          expect(billing[:invoice_grace_period]).to eq(3)
          expect(billing[:subscription_invoice_issuing_date_anchor]).to eq("current_period_end")
          expect(billing[:subscription_invoice_issuing_date_adjustment]).to eq("keep_anchor")
          expect(billing[:document_locale]).to eq("fr")
          expect(billing[:provider_payment_methods]).to eq(%w[card sepa_debit])
        end
      end

      context "when provider payment methods contain only card" do
        let(:provider_payment_methods) { %w[card] }

        it "returns a success" do
          expect(response).to have_http_status(:success)

          expect(json[:customer][:lago_id]).to be_present
          expect(json[:customer][:external_id]).to eq(create_params[:external_id])

          billing = json[:customer][:billing_configuration]

          expect(billing).to be_present
          expect(billing[:payment_provider]).to eq("stripe")
          expect(billing[:payment_provider_code]).to eq(stripe_provider.code)
          expect(billing[:provider_customer_id]).to eq("stripe_id")
          expect(billing[:invoice_grace_period]).to eq(3)
          expect(billing[:subscription_invoice_issuing_date_anchor]).to eq("current_period_end")
          expect(billing[:subscription_invoice_issuing_date_adjustment]).to eq("keep_anchor")
          expect(billing[:document_locale]).to eq("fr")
          expect(billing[:provider_payment_methods]).to eq(%w[card])
        end
      end

      context "when provider payment methods contain only sepa_debit" do
        let(:provider_payment_methods) { %w[sepa_debit] }

        it "returns a success" do
          expect(response).to have_http_status(:success)

          expect(json[:customer][:lago_id]).to be_present
          expect(json[:customer][:external_id]).to eq(create_params[:external_id])

          billing = json[:customer][:billing_configuration]

          expect(billing).to be_present
          expect(billing[:payment_provider]).to eq("stripe")
          expect(billing[:payment_provider_code]).to eq(stripe_provider.code)
          expect(billing[:provider_customer_id]).to eq("stripe_id")
          expect(billing[:invoice_grace_period]).to eq(3)
          expect(billing[:subscription_invoice_issuing_date_anchor]).to eq("current_period_end")
          expect(billing[:subscription_invoice_issuing_date_adjustment]).to eq("keep_anchor")
          expect(billing[:document_locale]).to eq("fr")
          expect(billing[:provider_payment_methods]).to eq(%w[sepa_debit])
        end
      end
    end

    context "with account_type partner", :premium do
      let(:organization) { create(:organization, premium_integrations: ["revenue_share"]) }

      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          account_type: "partner"
        }
      end

      it "returns a success" do
        subject
        expect(response).to have_http_status(:success)

        expect(json[:customer][:lago_id]).to be_present
        expect(json[:customer][:external_id]).to eq(create_params[:external_id])
        expect(json[:customer][:account_type]).to eq(create_params[:account_type])
      end
    end

    context "with integration_customers" do
      let!(:integration) { create(:netsuite_integration, organization:, code: "netsuite") }
      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          integration_customers: [
            {
              integration_type: "netsuite",
              integration_code: "netsuite",
              sync_with_provider: true
            }
          ]
        }
      end

      it "creates customer with integration customer and returns a success" do
        expect do
          subject
        end.to have_enqueued_job(IntegrationCustomers::CreateJob).with(
          integration_customer_params: {
            integration_type: "netsuite",
            integration_code: "netsuite",
            sync_with_provider: true
          },
          integration:,
          customer: a_kind_of(Customer)
        )
        expect(response).to have_http_status(:success)
      end
    end

    context "with metadata" do
      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          metadata: [
            {
              key: "Hello",
              value: "Hi",
              display_in_invoice: true
            }
          ]
        }
      end

      it "returns a success" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:customer][:lago_id]).to be_present
        expect(json[:customer][:external_id]).to eq(create_params[:external_id])

        metadata = json[:customer][:metadata]
        expect(metadata).to be_present
        expect(metadata.first[:key]).to eq("Hello")
        expect(metadata.first[:value]).to eq("Hi")
        expect(metadata.first[:display_in_invoice]).to eq(true)
      end
    end

    context "with invisible characters in email" do
      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar Inc.",
          email: "foo\u200Cbar@example.com",
          firstname: "Foo",
          lastname: "Bar",
          customer_type: "company",
          currency: "EUR",
          timezone: "America/New_York"
        }
      end

      it "removes invisible characters from email" do
        subject
        expect(response).to have_http_status(:success)
        expect(json[:customer][:email]).to eq("foobar@example.com")
      end

      context "with full range of invisible characters" do
        let(:create_params) do
          {
            external_id: SecureRandom.uuid,
            name: "Foo Bar Inc.",
            email: "foo\u200B\u200C\u200D\u00A0\u200E\u200Fbar@example.com",
            firstname: "Foo",
            lastname: "Bar",
            customer_type: "company"
          }
        end

        it "removes all invisible characters from email" do
          subject
          expect(response).to have_http_status(:success)
          expect(json[:customer][:email]).to eq("foobar@example.com")
        end
      end
    end

    [
      {
        params: "customer",
        expected_status: :bad_request,
        expected_response: {status: 400, error: "BadRequest: param is missing or the value is empty or invalid: customer"}
      },
      {
        params: {name: "Foo Bar", currency: "invalid"},
        expected_status: :unprocessable_content,
        expected_response: {
          status: 422,
          code: "validation_errors",
          error: "Unprocessable Entity",
          error_details: {
            currency: [
              "value_is_invalid"
            ],
            external_id: [
              "value_is_mandatory"
            ]
          }
        }
      }
    ].each do |test|
      context "with invalid params" do
        let(:create_params) { test[:params] }

        it "returns an unprocessable_entity" do
          subject
          expect(response).to have_http_status(test[:expected_status])
          expect(json).to eq(test[:expected_response])
        end
      end
    end

    context "with invoice_custom_sections" do
      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          skip_invoice_custom_sections:,
          invoice_custom_section_codes:
        }
      end
      let(:invoice_custom_sections) { create_list(:invoice_custom_section, 2, organization:) }

      before do
        create(
          :billing_entity_applied_invoice_custom_section,
          organization:,
          billing_entity: organization.default_billing_entity,
          invoice_custom_section: invoice_custom_sections[0]
        )
        subject
      end

      context "when sending custom invoice_custom_sections" do
        let(:skip_invoice_custom_sections) { false }
        let(:invoice_custom_section_codes) { invoice_custom_sections.map(&:code) }

        it "returns a success" do
          expect(response).to have_http_status(:success)

          expect(json[:customer][:lago_id]).to be_present
          expect(json[:customer][:external_id]).to eq(create_params[:external_id])

          sections = json[:customer][:applicable_invoice_custom_sections]
          expect(sections).to be_present
          expect(sections.length).to eq(2)
          expect(sections.map { |sec| sec[:code] }).to match_array(invoice_custom_section_codes)
        end
      end

      context "when sending skip_invoice_custom_sections AND invoice_custom_section_codes" do
        let(:skip_invoice_custom_sections) { true }
        let(:invoice_custom_section_codes) { invoice_custom_sections.map(&:code) }

        it "returns an error" do
          expect(response).to have_http_status(:unprocessable_content)

          expect(json[:error_details][:invoice_custom_sections]).to include("skip_sections_and_selected_ids_sent_together")
        end
      end
    end

    context "when billing_entity_code is provided" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:create_params) do
        {
          external_id: SecureRandom.uuid,
          name: "Foo Bar",
          billing_entity_code: billing_entity.code
        }
      end

      it "creates customer associated to the provided billing_entity" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:customer][:billing_entity_code]).to eq(billing_entity.code)
      end
    end
  end

  describe "GET /api/v1/customers/:customer_external_id/portal_url" do
    subject { get_with_token(organization, "/api/v1/customers/#{external_id}/portal_url") }

    let(:customer) { create(:customer, organization:) }
    let(:organization) { create(:organization) }
    let(:external_id) { customer.external_id }

    include_examples "requires API permission", "customer", "read"

    it "returns the portal url" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:customer][:portal_url]).to include("/customer-portal/")
    end

    context "when customer does not belongs to the organization" do
      let(:customer) { create(:customer) }

      it "returns not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/customers" do
    subject { get_with_token(organization, "/api/v1/customers", params) }

    let(:params) { {} }
    let(:organization) { create(:organization) }

    before { create_pair(:customer, organization:) }

    include_examples "requires API permission", "customer", "read"

    it "returns all customers from organization" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:meta][:total_count]).to eq(2)
      expect(json[:customers][0][:taxes]).not_to be_nil
    end

    context "with account_type filters" do
      let(:params) { {account_type: %w[partner]} }

      let(:partner) do
        create(:customer, organization:, account_type: "partner")
      end

      before { partner }

      it "returns partner customers" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:customers].count).to eq(1)
        expect(json[:customers].first[:lago_id]).to eq(partner.id)
      end
    end

    context "when filtering by customer_type" do
      let(:params) { {customer_type: "company"} }
      let!(:company) { create(:customer, organization:, customer_type: "company") }
      let(:individual) { create(:customer, organization:, customer_type: "individual") }

      before { individual }

      context "when filtering by company" do
        it "returns company customers" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:customers].count).to eq(1)
          expect(json[:customers].first[:lago_id]).to eq(company.id)
        end
      end
    end

    context "when filtering by has_customer_type" do
      let(:params) { {has_customer_type: true} }
      let!(:company) { create(:customer, organization:, customer_type: "company") }
      let!(:individual) { create(:customer, organization:, customer_type: "individual") }

      context "when filtering by true" do
        it "returns customers with customer_type" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:customers].count).to eq(2)
          expect(json[:customers].pluck(:lago_id)).to match_array([company.id, individual.id])
        end
      end

      context "when filtering by false and customer_type is provided" do
        let(:params) { {has_customer_type: false, customer_type: "company"} }

        it "returns an error" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(json).to match({
            code: "validation_errors",
            error: "Unprocessable Entity",
            error_details: {customer_type: ["must be nil when has_customer_type is false"]},
            status: 422
          })
        end
      end
    end

    context "when filtering by billing_entity_code" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:customer) { create(:customer, organization:, billing_entity:) }
      let(:params) { {billing_entity_codes: [billing_entity.code]} }

      before { customer }

      it "returns customers for the specified billing entity" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:customers].count).to eq(1)
        expect(json[:customers].first[:lago_id]).to eq(customer.id)
      end

      context "when one of billing entities does not exist" do
        let(:params) { {billing_entity_codes: [billing_entity.code, "non_existent_code"]} }

        it "returns a not found error" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json[:code]).to eq("billing_entity_not_found")
        end
      end

      context "with invalid billing entity codes" do
        let(:params) { {billing_entity_codes: "invalid_code"} }

        it "ignores the parameter" do
          subject

          expect(response).to have_http_status(:ok)
          expect(json[:customers].count).to eq(3)
          expect(json[:customers].first[:lago_id]).to eq(customer.id)
        end
      end

      context "with two identical billing entity codes" do
        let(:params) { {billing_entity_codes: [billing_entity.code, billing_entity.code]} }

        it "returns customers for the specified billing entity" do
          subject

          expect(response).to have_http_status(:ok)
          expect(json[:customers].count).to eq(1)
          expect(json[:customers].first[:lago_id]).to eq(customer.id)
        end
      end
    end

    context "when filtering by external_id" do
      let(:params) { {external_id: customer.external_id} }
      let!(:customer) { create(:customer, organization:) }

      it "returns customers with matching external_id" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:customers].count).to eq(1)
        expect(json[:customers].pluck(:lago_id)).to eq([customer.id])
      end
    end

    context "when filtering by countries" do
      let(:params) { {countries: ["US", "FR"]} }

      let!(:customer) { create(:customer, organization:, country: "US") }
      let!(:customer2) { create(:customer, organization:, country: "FR") }

      it "returns only two customers" do
        subject
        expect(response).to have_http_status(:success)
        expect(json[:customers].count).to eq(2)
        expect(json[:customers].map { |customer| customer[:lago_id] }).to match_array([customer.id, customer2.id])
      end

      context "when filtering by invalid country" do
        let(:params) { {countries: ["INVALID"]} }

        it "returns no customers" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(json).to match({
            code: "validation_errors",
            error: "Unprocessable Entity",
            error_details: {countries: {"0": [/must be one of: AD, .*XK$/]}},
            status: 422
          })
        end
      end
    end

    context "when filtering by states" do
      let(:params) { {states: ["CA", "Paris"]} }
      let!(:customer) { create(:customer, organization:, state: "CA") }
      let!(:customer2) { create(:customer, organization:, state: "Paris") }

      it "returns only two customers" do
        subject
        expect(response).to have_http_status(:success)
        expect(json[:customers].count).to eq(2)
        expect(json[:customers].map { |customer| customer[:lago_id] }).to match_array([customer.id, customer2.id])
      end
    end

    context "when filtering by zipcodes" do
      let(:params) { {zipcodes: ["10115", "75001"]} }
      let!(:customer) { create(:customer, organization:, zipcode: "10115") }
      let!(:customer2) { create(:customer, organization:, zipcode: "75001") }

      it "returns only two customers" do
        subject
        expect(response).to have_http_status(:success)
        expect(json[:customers].count).to eq(2)
        expect(json[:customers].map { |customer| customer[:lago_id] }).to match_array([customer.id, customer2.id])
      end
    end

    context "when filtering by currencies" do
      let(:params) { {currencies: ["AED", "CAD"]} }
      let!(:customer) { create(:customer, organization:, currency: "AED") }
      let!(:customer2) { create(:customer, organization:, currency: "CAD") }

      it "returns only two customers" do
        subject
        expect(response).to have_http_status(:success)
        expect(json[:customers].count).to eq(2)
        expect(json[:customers].map { |customer| customer[:lago_id] }).to match_array([customer.id, customer2.id])
      end

      context "when filtering by invalid currency" do
        let(:params) { {currencies: ["INVALID"]} }

        it "returns no customers" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(json).to match({
            code: "validation_errors",
            error: "Unprocessable Entity",
            error_details: {currencies: {"0": [/must be one of: AED, AFN.*ZMW$/]}},
            status: 422
          })
        end
      end
    end

    context "when filtering by has_tax_identification_number" do
      let(:params) { {has_tax_identification_number: true} }
      let!(:customer) { create(:customer, organization:, tax_identification_number: "1234567890") }

      it "returns only the customer with a tax identification number" do
        subject
        expect(response).to have_http_status(:success)
        expect(json[:customers].count).to eq(1)
        expect(json[:customers].map { |customer| customer[:lago_id] }).to match_array([customer.id])
      end

      context "when filtering by false" do
        let(:params) { {has_tax_identification_number: false} }

        it "returns only the customer without a tax identification number" do
          subject
          expect(response).to have_http_status(:success)
          expect(json[:customers].count).to eq(2)
          expect(json[:customers].map { |customer| customer[:lago_id] }).not_to include(customer.id)
        end
      end

      context "when filtering by invalid value" do
        let(:params) { {has_tax_identification_number: "invalid"} }

        it "returns no customers" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(json).to match({
            code: "validation_errors",
            error: "Unprocessable Entity",
            error_details: {has_tax_identification_number: ["must be one of: true, false"]},
            status: 422
          })
        end
      end
    end

    context "when filtering by metadata" do
      let(:params) { {metadata: {is_synced: "true", last_synced_at: "2025-01-01", first_synced_at: ""}} }
      let!(:customer) { create(:customer, organization:) }

      before do
        create(:customer_metadata, customer:, key: "is_synced", value: "true")
        create(:customer_metadata, customer:, key: "last_synced_at", value: "2025-01-01")
      end

      it "returns only the customer with the specified metadata" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:customers].count).to eq(1)
        expect(json[:customers].map { |customer| customer[:lago_id] }).to match_array([customer.id])
      end

      context "when filtering by invalid metadata" do
        let(:params) { {metadata: {nested: {deeply: true}, is_synced: ["true"]}} }

        it "returns no customers" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(json).to match({
            code: "validation_errors",
            error: "Unprocessable Entity",
            error_details: {metadata: {is_synced: ["must be a string"], nested: ["must be a string"]}},
            status: 422
          })
        end
      end
    end

    context "when filtering by search_term" do
      let(:params) { {search_term: "oo b"} }
      let!(:customer) { create(:customer, organization:, name: "Foo Bar") }

      it "returns customers for the specified search_term" do
        subject

        expect(response).to have_http_status(:ok)

        expect(json[:customers].count).to eq(1)
        expect(json[:customers].first[:lago_id]).to eq(customer.id)
      end
    end
  end

  describe "GET /api/v1/customers/:customer_id" do
    subject { get_with_token(organization, "/api/v1/customers/#{external_id}") }

    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:external_id) { customer.external_id }

    context "when customer exists" do
      include_examples "requires API permission", "customer", "read"

      it "returns the customer" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:customer][:lago_id]).to eq(customer.id)
        expect(json[:customer][:taxes]).not_to be_nil
      end
    end

    context "when customer does not exist" do
      let(:external_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/customers/:customer_id" do
    subject { delete_with_token(organization, "/api/v1/customers/#{external_id}") }

    let(:organization) { create(:organization) }
    let!(:customer) { create(:customer, organization:) }
    let(:external_id) { customer.external_id }

    include_examples "requires API permission", "customer", "write"

    it "deletes a customer" do
      expect { subject }.to change(Customer, :count).by(-1)
    end

    it "returns deleted customer" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:customer][:lago_id]).to eq(customer.id)
      expect(json[:customer][:external_id]).to eq(customer.external_id)
    end

    context "when customer does not exist" do
      let(:external_id) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/customers/:external_customer_id/checkout_url" do
    subject do
      post_with_token(organization, "/api/v1/customers/#{customer.external_id}/checkout_url")
    end

    let(:organization) { create(:organization) }
    let(:stripe_provider) { create(:stripe_provider, organization:) }
    let(:customer) { create(:customer, organization:) }

    before do
      create(
        :stripe_customer,
        customer_id: customer.id,
        payment_provider: stripe_provider
      )

      customer.update!(payment_provider: "stripe", payment_provider_code: stripe_provider.code)

      allow(::Stripe::Checkout::Session).to receive(:create)
        .and_return({"url" => "https://example.com"})
    end

    include_examples "requires API permission", "customer", "write"

    it "returns the new generated checkout url" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:customer][:checkout_url]).to eq("https://example.com")
    end
  end
end
