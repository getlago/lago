# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::BillingEntitiesController do
  let(:billing_entity1) { create(:billing_entity) }
  let(:organization) { billing_entity1.organization }
  let(:billing_entity2) { create(:billing_entity, organization:) }
  let(:billing_entity3) { create(:billing_entity) }
  let(:billing_entity4) { create(:billing_entity, :deleted, organization:) }
  let(:billing_entity5) { create(:billing_entity, :archived, organization:) }

  describe "GET /api/v1/billing_entities" do
    subject do
      get_with_token(organization, "/api/v1/billing_entities")
    end

    before do
      billing_entity1
      billing_entity2
      billing_entity3
      billing_entity4
      billing_entity5
    end

    it "returns a list of active not archived billing entities" do
      subject
      expect(response).to be_successful
      expect(json[:billing_entities].count).to eq(2)
      expect(json[:billing_entities].map { |billing_entity| billing_entity[:lago_id] }).to include(billing_entity1.id, billing_entity2.id)
    end
  end

  describe "GET /api/v1/billing_entities/:code" do
    subject do
      get_with_token(organization, "/api/v1/billing_entities/#{billing_entity1.code}")
    end

    it "returns a billing entity" do
      subject
      expect(response).to be_successful
      expect(json[:billing_entity][:lago_id]).to eq(billing_entity1.id)
      expect(json[:billing_entity]).to have_key :selected_invoice_custom_sections
    end

    context "when the billing entity has applied taxes" do
      let(:tax) { create(:tax) }
      let(:applied_tax) { create(:billing_entity_applied_tax, billing_entity: billing_entity1, tax:) }

      before { applied_tax }

      it "returns the billing entity with the applied taxes" do
        subject
        expect(json[:billing_entity][:taxes].count).to eq(1)
      end
    end

    context "when the billing entity from another organization is requested" do
      subject do
        get_with_token(organization, "/api/v1/billing_entities/#{billing_entity3.code}")
      end

      it "returns a 404" do
        subject
        expect(response).to be_not_found
      end
    end

    context "when the billing entity is archived" do
      subject do
        get_with_token(organization, "/api/v1/billing_entities/#{billing_entity5.code}")
      end

      it "returns billing entity" do
        subject
        expect(response).to be_successful
        expect(json[:billing_entity][:lago_id]).to eq(billing_entity5.id)
      end
    end

    context "when the billing entity is deleted" do
      subject do
        get_with_token(organization, "/api/v1/billing_entities/#{billing_entity4.code}")
      end

      it "returns a 404" do
        subject
        expect(response).to be_not_found
      end
    end
  end

  describe "POST /api/v1/billing_entities", :premium do
    subject do
      post_with_token(organization, "/api/v1/billing_entities", create_params)
    end

    include_context "with mocked security logger"

    let(:organization) { create(:organization, premium_integrations: %w[multi_entities_enterprise]) }

    let(:create_params) do
      {
        billing_entity: {
          code: billing_entity_code,
          name: "New Name",
          email: "new@email.com",
          legal_name: "New Legal Name",
          einvoicing: false,
          legal_number: "1234567890",
          tax_identification_number: "Tax-1234",
          address_line1: "Calle de la Princesa 1",
          address_line2: "Apt 1",
          phone: "+49 30 1234567",
          city: "Barcelona",
          state: "Barcelona",
          zipcode: "08001",
          country: "ES",
          default_currency: "EUR",
          timezone: "Europe/Madrid",
          document_numbering: "per_billing_entity",
          document_number_prefix: "NEW-0001",
          finalize_zero_amount_invoice: true,
          net_payment_term: 10,
          eu_tax_management: true,
          logo:,
          email_settings: ["invoice.finalized", "credit_note.created"],
          billing_configuration: {
            invoice_footer: "New Invoice Footer",
            document_locale: "es",
            invoice_grace_period: 10,
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "keep_anchor"
          }
        }
      }
    end

    let(:billing_entity_code) { "NEW-0001" }

    let(:logo) do
      logo_file = File.read(Rails.root.join("spec/factories/images/logo.png"))
      base64_logo = Base64.encode64(logo_file)

      "data:image/png;base64,#{base64_logo}"
    end

    it "creates a billing entity" do
      subject
      expect(response).to be_successful
      expect(json[:billing_entity][:lago_id]).to be_a(String)
      expect(json[:billing_entity][:code]).to eq("NEW-0001")
      expect(json[:billing_entity][:name]).to eq("New Name")
      expect(json[:billing_entity][:email]).to eq("new@email.com")
      expect(json[:billing_entity][:einvoicing]).to eq(false)
      expect(json[:billing_entity][:legal_name]).to eq("New Legal Name")
      expect(json[:billing_entity][:legal_number]).to eq("1234567890")
      expect(json[:billing_entity][:tax_identification_number]).to eq("Tax-1234")
      expect(json[:billing_entity][:address_line1]).to eq("Calle de la Princesa 1")
      expect(json[:billing_entity][:address_line2]).to eq("Apt 1")
      expect(json[:billing_entity][:phone]).to eq("+49 30 1234567")
      expect(json[:billing_entity][:city]).to eq("Barcelona")
      expect(json[:billing_entity][:state]).to eq("Barcelona")
      expect(json[:billing_entity][:zipcode]).to eq("08001")
      expect(json[:billing_entity][:country]).to eq("ES")
      expect(json[:billing_entity][:default_currency]).to eq("EUR")
      expect(json[:billing_entity][:timezone]).to eq("Europe/Madrid")
      expect(json[:billing_entity][:document_numbering]).to eq("per_billing_entity")
      expect(json[:billing_entity][:document_number_prefix]).to eq("NEW-0001")
      expect(json[:billing_entity][:finalize_zero_amount_invoice]).to eq(true)
      expect(json[:billing_entity][:net_payment_term]).to eq(10)
      expect(json[:billing_entity][:eu_tax_management]).to eq(true)
      expect(json[:billing_entity][:email_settings]).to eq(["invoice.finalized", "credit_note.created"])
      expect(json[:billing_entity][:invoice_footer]).to eq("New Invoice Footer")
      expect(json[:billing_entity][:document_locale]).to eq("es")
      expect(json[:billing_entity][:invoice_grace_period]).to eq(10)
      expect(json[:billing_entity][:subscription_invoice_issuing_date_anchor]).to eq("current_period_end")
      expect(json[:billing_entity][:subscription_invoice_issuing_date_adjustment]).to eq("keep_anchor")
      expect(json[:billing_entity][:logo_url]).to match(%r{.*/rails/active_storage/blobs/redirect/.*/logo})
    end

    it_behaves_like "produces a security log", "billing_entity.created" do
      before { subject }
    end

    context "when the logo is not provided" do
      let(:logo) { nil }

      it "returns a 200" do
        subject
        expect(response).to be_successful
        expect(json[:billing_entity][:logo_url]).to be_nil
      end
    end

    context "when the code is already taken" do
      let(:billing_entity_code) { organization.default_billing_entity.code }

      it "returns a 422" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error]).to eq("Unprocessable Entity")
        expect(json[:error_details]).to eq(code: ["value_already_exist"])
      end
    end

    context "when the organization has no remaining billing entities" do
      let(:organization) { create(:organization) }

      it "returns a 403" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:error]).to eq("Forbidden")
        expect(json[:code]).to eq("feature_unavailable")
      end
    end
  end

  describe "PUT /api/v1/billing_entities/:code", :premium do
    subject do
      put_with_token(organization, "/api/v1/billing_entities/#{billing_entity_code}", update_params)
    end

    include_context "with mocked security logger"

    let(:billing_entity_code) { billing_entity1.code }

    let(:update_params) do
      {
        billing_entity: {
          name: "New Name",
          email: "new@email.com",
          einvoicing: false,
          legal_name: "New Legal Name",
          legal_number: "1234567890",
          tax_identification_number: "Tax-1234",
          address_line1: "Calle de la Princesa 1",
          address_line2: "Apt 1",
          phone: "+49 30 1234567",
          city: "Barcelona",
          state: "Barcelona",
          zipcode: "08001",
          country: "ES",
          default_currency: "EUR",
          timezone: "Europe/Madrid",
          document_numbering: "per_billing_entity",
          document_number_prefix: "NEW-0001",
          finalize_zero_amount_invoice: true,
          net_payment_term: 10,
          eu_tax_management: true,
          logo: logo,
          email_settings: ["invoice.finalized", "credit_note.created"],
          billing_configuration: {
            invoice_footer: "New Invoice Footer",
            document_locale: "es",
            invoice_grace_period: 10,
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "keep_anchor"
          }
        }
      }
    end

    let(:logo) do
      logo_file = File.read(Rails.root.join("spec/factories/images/logo.png"))
      base64_logo = Base64.encode64(logo_file)

      "data:image/png;base64,#{base64_logo}"
    end

    it "updates the billing entity" do
      subject

      expect(response).to be_successful
      expect(billing_entity1.reload.name).to eq("New Name")

      expect(json[:billing_entity][:name]).to eq("New Name")
      expect(json[:billing_entity][:email]).to eq("new@email.com")
      expect(json[:billing_entity][:einvoicing]).to eq(false)
      expect(json[:billing_entity][:legal_name]).to eq("New Legal Name")
      expect(json[:billing_entity][:legal_number]).to eq("1234567890")
      expect(json[:billing_entity][:tax_identification_number]).to eq("Tax-1234")
      expect(json[:billing_entity][:address_line1]).to eq("Calle de la Princesa 1")
      expect(json[:billing_entity][:address_line2]).to eq("Apt 1")
      expect(json[:billing_entity][:phone]).to eq("+49 30 1234567")
      expect(json[:billing_entity][:city]).to eq("Barcelona")
      expect(json[:billing_entity][:state]).to eq("Barcelona")
      expect(json[:billing_entity][:zipcode]).to eq("08001")
      expect(json[:billing_entity][:country]).to eq("ES")
      expect(json[:billing_entity][:default_currency]).to eq("EUR")
      expect(json[:billing_entity][:timezone]).to eq("Europe/Madrid")
      expect(json[:billing_entity][:document_numbering]).to eq("per_billing_entity")
      expect(json[:billing_entity][:document_number_prefix]).to eq("NEW-0001")
      expect(json[:billing_entity][:finalize_zero_amount_invoice]).to eq(true)
      expect(json[:billing_entity][:net_payment_term]).to eq(10)
      expect(json[:billing_entity][:eu_tax_management]).to eq(true)
      expect(json[:billing_entity][:email_settings]).to eq(["invoice.finalized", "credit_note.created"])
      expect(json[:billing_entity][:invoice_footer]).to eq("New Invoice Footer")
      expect(json[:billing_entity][:document_locale]).to eq("es")
      expect(json[:billing_entity][:invoice_grace_period]).to eq(10)
      expect(json[:billing_entity][:subscription_invoice_issuing_date_anchor]).to eq("current_period_end")
      expect(json[:billing_entity][:subscription_invoice_issuing_date_adjustment]).to eq("keep_anchor")
      expect(json[:billing_entity][:logo_url]).to match(%r{.*/rails/active_storage/blobs/redirect/.*/logo})
    end

    it_behaves_like "produces a security log", "billing_entity.updated" do
      before { subject }
    end

    context "when updating the applicable invoice custom sections" do
      let(:update_params) do
        {
          billing_entity: {
            invoice_custom_section_codes: [custom_section.code]
          }
        }
      end

      let(:custom_section) { create(:invoice_custom_section, organization:) }

      it "updates the applicable invoice custom sections" do
        subject

        expect(response).to be_successful
        expect(billing_entity1.reload.selected_invoice_custom_sections.count).to eq(1)
        expect(billing_entity1.selected_invoice_custom_sections.first.code).to eq(custom_section.code)
        expect(json[:billing_entity][:selected_invoice_custom_sections].count).to eq(1)
      end
    end

    context "when updating billing_entity taxes" do
      let(:tax1) { create(:tax, organization:, code: "TAX_CODE_1") }
      let(:tax2) { create(:tax, organization:, code: "TAX_CODE_2") }
      let(:update_params) do
        {
          billing_entity: {
            tax_codes: [tax2.code]
          }
        }
      end

      before do
        create(:billing_entity_applied_tax, billing_entity: billing_entity1, tax: tax1)
      end

      it "updates the taxes" do
        subject
        expect(billing_entity1.reload.taxes.count).to eq(1)
        expect(billing_entity1.taxes.map(&:code)).to include("TAX_CODE_2")
      end

      context "when the tax is not found" do
        let(:update_params) do
          {
            billing_entity: {
              tax_codes: ["NON_EXISTING_CODE"]
            }
          }
        end

        it "returns a 404" do
          subject
          expect(response).to be_not_found
        end
      end
    end

    context "when the billing entity is not found" do
      let(:billing_entity_code) { "NON_EXISTING_CODE" }

      it "returns a 404" do
        subject
        expect(response).to be_not_found
      end
    end
  end
end
