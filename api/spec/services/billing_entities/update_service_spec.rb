# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntities::UpdateService do
  subject(:update_service) { described_class.new(billing_entity:, params:) }

  include_context "with mocked security logger"

  let(:billing_entity) { create(:billing_entity) }
  let(:organization) { billing_entity.organization }

  let(:timezone) { nil }
  let(:email_settings) { [] }
  let(:invoice_grace_period) { 0 }
  let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
  let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
  let(:logo) { nil }
  let(:country) { "fr" }
  let(:einvoicing) { true }

  let(:params) do
    {
      name: "New Name",
      legal_name: "Foobar",
      legal_number: "1234",
      tax_identification_number: "2246",
      email: "foo@bar.com",
      einvoicing:,
      address_line1: "Line 1",
      address_line2: "Line 2",
      phone: "+49 30 1234567",
      state: "Foobar",
      zipcode: "FOO1234",
      city: "Foobar",
      default_currency: "EUR",
      country:,
      timezone:,
      logo:,
      email_settings:,
      billing_configuration: {
        invoice_footer: "invoice footer",
        document_locale: "fr",
        invoice_grace_period:,
        subscription_invoice_issuing_date_anchor:,
        subscription_invoice_issuing_date_adjustment:
      }
    }
  end

  describe "#call" do
    it "updates the billing_entity" do
      result = update_service.call

      expect(result.billing_entity.name).to eq("New Name")
      expect(result.billing_entity.legal_name).to eq("Foobar")
      expect(result.billing_entity.legal_number).to eq("1234")
      expect(result.billing_entity.tax_identification_number).to eq("2246")
      expect(result.billing_entity.email).to eq("foo@bar.com")
      expect(result.billing_entity.address_line1).to eq("Line 1")
      expect(result.billing_entity.einvoicing).to eq(true)
      expect(result.billing_entity.address_line2).to eq("Line 2")
      expect(result.billing_entity.phone).to eq("+49 30 1234567")
      expect(result.billing_entity.state).to eq("Foobar")
      expect(result.billing_entity.zipcode).to eq("FOO1234")
      expect(result.billing_entity.city).to eq("Foobar")
      expect(result.billing_entity.country).to eq("FR")
      expect(result.billing_entity.default_currency).to eq("EUR")
      expect(result.billing_entity.timezone).to eq("UTC")

      expect(result.billing_entity.invoice_footer).to eq("invoice footer")
      expect(result.billing_entity.document_locale).to eq("fr")
    end

    context "with email containing unicode lookalike characters" do
      let(:params) { {email: "hello@something\u2013other.com"} }

      it "sanitizes the email before saving" do
        result = update_service.call
        expect(result.billing_entity.email).to eq("hello@something-other.com")
      end
    end

    it_behaves_like "produces a security log", "billing_entity.updated" do
      before { update_service.call }
    end

    context "when tax_codes are changed" do
      let(:old_tax) { create(:tax, organization:, code: "old_tax") }
      let(:new_tax) { create(:tax, organization:, code: "new_tax") }
      let(:kept_tax) { create(:tax, organization:, code: "kept_tax") }
      let(:params) { {tax_codes: %w[new_tax kept_tax]} }

      before do
        create(:billing_entity_applied_tax, billing_entity:, tax: old_tax)
        create(:billing_entity_applied_tax, billing_entity:, tax: kept_tax)
        new_tax
      end

      it_behaves_like "produces a security log", "billing_entity.updated" do
        before { update_service.call }
      end
    end

    it "produces an activity log" do
      described_class.call(billing_entity:, params:)

      expect(Utils::ActivityLog).to have_produced("billing_entities.updated").after_commit.with(billing_entity)
    end

    context "when document_number_prefix is sent" do
      before { params[:document_number_prefix] = "abc" }

      it "converts document_number_prefix to upcase version" do
        result = update_service.call

        expect(result.billing_entity.document_number_prefix).to eq("ABC")
      end
    end

    context "when finalize_zero_amount_invoice is sent" do
      before { params[:finalize_zero_amount_invoice] = "false" }

      it "sets finalize_zero_amount_invoice" do
        result = update_service.call

        expect(result.billing_entity.finalize_zero_amount_invoice).to eq(false)
      end
    end

    context "when document_number_prefix is invalid" do
      before { params[:document_number_prefix] = "aaaaaaaaaaaaaaa" }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:document_number_prefix]).to eq(["value_is_too_long"])
      end
    end

    context "with premium features", :premium do
      let(:timezone) { "Europe/Paris" }
      let(:email_settings) { ["invoice.finalized"] }

      it "updates the billing_entity" do
        result = update_service.call

        expect(result.billing_entity.timezone).to eq("Europe/Paris")
        expect(result.billing_entity.subscription_invoice_issuing_date_anchor).to eq("current_period_end")
        expect(result.billing_entity.subscription_invoice_issuing_date_adjustment).to eq("keep_anchor")
      end

      context "when updating invoice grace period" do
        let(:customer) { create(:customer, billing_entity:) }

        let(:invoice_grace_period) { 2 }

        it "triggers async updates grace_period of invoices" do
          old_invoice_grace_period = billing_entity.invoice_grace_period
          result = update_service.call

          expect(result.billing_entity.invoice_grace_period).to eq(2)
          expect(Invoices::UpdateAllInvoiceIssuingDateFromBillingEntityJob).to have_been_enqueued.with(
            billing_entity,
            invoice_grace_period: old_invoice_grace_period,
            subscription_invoice_issuing_date_anchor: "next_period_start",
            subscription_invoice_issuing_date_adjustment: "align_with_finalization_date"
          )
        end
      end

      context "when updating net_payment_term" do
        let(:customer) { create(:customer, billing_entity:) }

        let(:params) do
          {
            net_payment_term: 2
          }
        end

        before do
          allow(BillingEntities::UpdateInvoicePaymentDueDateService).to receive(:call).and_call_original
        end

        it "updates the corresponding draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            result = update_service.call
            expect(result).to be_success

            expect(result.billing_entity.net_payment_term).to eq(2)
            expect(BillingEntities::UpdateInvoicePaymentDueDateService).to have_received(:call).with(billing_entity:, net_payment_term: 2)
          end
        end
      end
    end

    context "with base64 logo" do
      let(:logo) do
        logo_file = File.read(Rails.root.join("spec/factories/images/logo.png"))
        base64_logo = Base64.encode64(logo_file)

        "data:image/png;base64,#{base64_logo}"
      end

      it "updates the billing_entity with logo" do
        result = update_service.call
        expect(result.billing_entity.logo.blob).not_to be_nil
      end
    end

    context "when logo is set but then removed" do
      let(:logo) do
        logo_file = File.read(Rails.root.join("spec/factories/images/logo.png"))
        base64_logo = Base64.encode64(logo_file)

        "data:image/png;base64,#{base64_logo}"
      end

      it "removes the logo" do
        update_service.call
        result = described_class.new(billing_entity:, params: {logo: nil}).call
        expect(result.billing_entity.logo.blob).to be_nil
      end
    end

    context "with validation errors" do
      context "when invalid country" do
        let(:country) { "---" }

        it "returns an error" do
          result = update_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:country]).to eq(["not_a_valid_country_code"])
        end
      end
    end

    context "when enable einvoicing" do
      before { billing_entity.update(einvoicing: true) }

      context "when country is not supported" do
        let(:country) { "BR" }

        it "returns an error" do
          result = update_service.call
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:einvoicing]).to eq(["country_not_supported"])
        end
      end

      context "when country is nil" do
        let(:country) { nil }

        it "returns an error" do
          result = update_service.call
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:einvoicing]).to eq(["country_must_be_present"])
        end
      end

      context "when country is supported" do
        let(:country) { "DE" }

        it "enables einvoicing on the billing entity" do
          result = update_service.call

          expect(result).to be_success
          expect(result.billing_entity.einvoicing).to be true
          expect(result.billing_entity.country).to eq(country)
        end
      end
    end

    context "with eu tax management" do
      context "with org within the EU" do
        let(:params) { {eu_tax_management: true, country: "fr"} }

        before do
          allow(BillingEntities::ChangeEuTaxManagementService).to receive(:call).and_call_original
        end

        it "calls the taxes auto generate service" do
          result = update_service.call

          expect(result).to be_success
          expect(BillingEntities::ChangeEuTaxManagementService)
            .to have_received(:call)
            .with(billing_entity:, eu_tax_management: true)
        end
      end

      context "with org outside the EU" do
        let(:params) { {eu_tax_management: true, country: "us"} }

        before do
          allow(BillingEntities::ChangeEuTaxManagementService).to receive(:call).and_call_original
        end

        it "calls the taxes auto generate service" do
          result = update_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({eu_tax_management: ["billing_entity_must_be_in_eu"]})
          expect(BillingEntities::ChangeEuTaxManagementService)
            .to have_received(:call)
            .with(billing_entity:, eu_tax_management: true)
        end
      end

      context "with org is outside the EU but feature is already enabled" do
        let(:params) { {eu_tax_management: false} }

        before do
          billing_entity.country = "us"
          billing_entity.eu_tax_management = true
          allow(BillingEntities::ChangeEuTaxManagementService).to receive(:call).and_call_original
        end

        it "can disable eu_tax_management" do
          result = update_service.call

          expect(result).to be_success
          expect(BillingEntities::ChangeEuTaxManagementService)
            .to have_received(:call)
        end
      end
    end

    context "when updating invoice_custom_sections" do
      let(:params) { {invoice_custom_section_ids: [invoice_custom_section_1.id, invoice_custom_section_2.id]} }

      let(:invoice_custom_section_1) { create(:invoice_custom_section, organization:) }
      let(:invoice_custom_section_2) { create(:invoice_custom_section, organization:) }

      it "updates the billing_entity" do
        result = update_service.call

        expect(result.billing_entity.selected_invoice_custom_sections).to contain_exactly(invoice_custom_section_1, invoice_custom_section_2)
      end

      context "when removing a section" do
        let(:params) { {invoice_custom_section_ids: [invoice_custom_section_1.id]} }

        before do
          create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_2)
        end

        it "removes the section" do
          result = update_service.call

          expect(result.billing_entity.selected_invoice_custom_sections).to contain_exactly(invoice_custom_section_1)
        end
      end

      context "when adding a section" do
        let(:params) { {invoice_custom_section_ids: [invoice_custom_section_1.id, invoice_custom_section_2.id]} }

        before do
          create(:billing_entity_applied_invoice_custom_section, billing_entity:, invoice_custom_section: invoice_custom_section_2)
        end

        it "adds the section" do
          result = update_service.call

          expect(result.billing_entity.selected_invoice_custom_sections).to contain_exactly(invoice_custom_section_1, invoice_custom_section_2)
        end
      end

      context "when removing all sections" do
        let(:params) { {invoice_custom_section_ids: []} }

        it "removes all sections" do
          result = update_service.call

          expect(result.billing_entity.selected_invoice_custom_sections).to be_empty
        end
      end

      context "when invoice_custom_section_codes are provided" do
        let(:params) do
          {invoice_custom_section_codes: [invoice_custom_section_1.code, invoice_custom_section_2.code]}
        end

        it "updates the billing_entity" do
          result = update_service.call

          expect(result.billing_entity.selected_invoice_custom_sections).to contain_exactly(invoice_custom_section_1, invoice_custom_section_2)
        end

        context "when removing a section" do
          let(:params) { {invoice_custom_section_codes: [invoice_custom_section_1.code]} }

          before do
            create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: invoice_custom_section_2)
          end

          it "removes the section" do
            result = update_service.call

            expect(result.billing_entity.selected_invoice_custom_sections).to contain_exactly(invoice_custom_section_1)
          end
        end

        context "when adding a section" do
          let(:params) { {invoice_custom_section_codes: [invoice_custom_section_1.code, invoice_custom_section_2.code]} }

          before do
            create(:billing_entity_applied_invoice_custom_section, billing_entity:, invoice_custom_section: invoice_custom_section_2)
          end

          it "adds the section" do
            result = update_service.call

            expect(result.billing_entity.selected_invoice_custom_sections).to contain_exactly(invoice_custom_section_1, invoice_custom_section_2)
          end
        end

        context "when removing all sections" do
          let(:params) { {invoice_custom_section_cods: []} }

          it "removes all sections" do
            result = update_service.call

            expect(result.billing_entity.selected_invoice_custom_sections).to be_empty
          end
        end
      end
    end

    context "when billing_entity is not provided" do
      let(:billing_entity) { nil }

      it "raises an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("billing_entity")
      end

      it_behaves_like "does not produce a security log" do
        before { update_service.call }
      end
    end
  end
end
