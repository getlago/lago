# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::UpdateService do
  subject(:update_service) { described_class.new(organization:, params:) }

  let(:organization) { create(:organization) }

  let(:timezone) { nil }
  let(:email_settings) { [] }
  let(:invoice_grace_period) { 0 }
  let(:logo) { nil }
  let(:country) { "fr" }

  let(:params) do
    {
      legal_name: "Foobar",
      legal_number: "1234",
      tax_identification_number: "2246",
      email: "foo@bar.com",
      address_line1: "Line 1",
      address_line2: "Line 2",
      state: "Foobar",
      zipcode: "FOO1234",
      city: "Foobar",
      default_currency: "EUR",
      country:,
      timezone:,
      logo:,
      email_settings:,
      authentication_methods: ["email_password"],
      billing_configuration: {
        invoice_footer: "invoice footer",
        document_locale: "fr",
        invoice_grace_period:
      }
    }
  end

  describe "#call" do
    it "updates the organization" do
      result = update_service.call

      expect(result.organization.legal_name).to eq("Foobar")
      expect(result.organization.legal_number).to eq("1234")
      expect(result.organization.tax_identification_number).to eq("2246")
      expect(result.organization.email).to eq("foo@bar.com")
      expect(result.organization.address_line1).to eq("Line 1")
      expect(result.organization.address_line2).to eq("Line 2")
      expect(result.organization.state).to eq("Foobar")
      expect(result.organization.zipcode).to eq("FOO1234")
      expect(result.organization.city).to eq("Foobar")
      expect(result.organization.country).to eq("FR")
      expect(result.organization.default_currency).to eq("EUR")
      expect(result.organization.timezone).to eq("UTC")
      expect(result.organization.authentication_methods).to eq(["email_password"])

      expect(result.organization.invoice_footer).to eq("invoice footer")
      expect(result.organization.document_locale).to eq("fr")
    end

    context "with email containing unicode lookalike characters" do
      let(:params) { {email: "hello@something\u2013other.com"} }

      it "sanitizes the email before saving" do
        result = update_service.call
        expect(result.organization.email).to eq("hello@something-other.com")
      end
    end

    it "updates default billing_entity" do
      result = update_service.call

      default_billing_entity = result.organization.default_billing_entity
      expect(default_billing_entity.legal_name).to eq("Foobar")
      expect(default_billing_entity.legal_number).to eq("1234")
      expect(default_billing_entity.tax_identification_number).to eq("2246")
      expect(default_billing_entity.email).to eq("foo@bar.com")
      expect(default_billing_entity.address_line1).to eq("Line 1")
      expect(default_billing_entity.address_line2).to eq("Line 2")
      expect(default_billing_entity.state).to eq("Foobar")
      expect(default_billing_entity.zipcode).to eq("FOO1234")
      expect(default_billing_entity.city).to eq("Foobar")
      expect(default_billing_entity.country).to eq("FR")
      expect(default_billing_entity.default_currency).to eq("EUR")
      expect(default_billing_entity.timezone).to eq("UTC")

      expect(default_billing_entity.invoice_footer).to eq("invoice footer")
      expect(default_billing_entity.document_locale).to eq("fr")
    end

    context "when document_number_prefix is sent" do
      before { params[:document_number_prefix] = "abc" }

      it "converts document_number_prefix to upcase version" do
        result = update_service.call

        expect(result.organization.document_number_prefix).to eq("ABC")
      end
    end

    context "when finalize_zero_amount_invoice is sent" do
      before { params[:finalize_zero_amount_invoice] = "false" }

      it "converts document_number_prefix to upcase version" do
        result = update_service.call

        expect(result.organization.finalize_zero_amount_invoice).to eq(false)
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

    context "when slug is sent" do
      before { params[:slug] = "new-slug" }

      it "updates the organization slug" do
        result = update_service.call

        expect(result).to be_success
        expect(result.organization.slug).to eq("new-slug")
      end
    end

    context "when slug has mixed case and whitespace" do
      before { params[:slug] = "  My-Slug  " }

      it "normalizes the slug before saving" do
        result = update_service.call

        expect(result).to be_success
        expect(result.organization.slug).to eq("my-slug")
      end
    end

    context "when slug is invalid" do
      before { params[:slug] = "INVALID SLUG!" }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:slug]).to be_present
      end
    end

    context "when slug is already taken" do
      before do
        create(:organization, slug: "taken-slug")
        params[:slug] = "taken-slug"
      end

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:slug]).to be_present
      end
    end

    context "when slug is a reserved word" do
      before { params[:slug] = "customers" }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:slug]).to be_present
      end
    end

    context "with premium features", :premium do
      let(:timezone) { "Europe/Paris" }
      let(:email_settings) { ["invoice.finalized"] }

      it "updates the organization" do
        result = update_service.call

        expect(result.organization.timezone).to eq("Europe/Paris")
      end

      context "when updating invoice grace period" do
        let(:customer) { create(:customer, organization:) }
        let(:invoice_grace_period) { 2 }

        let(:invoice_to_be_finalized) do
          create(:invoice, status: :draft, customer:, issuing_date: DateTime.parse("19 Jun 2022").to_date, organization:)
        end

        let(:invoice_to_not_be_finalized) do
          create(:invoice, status: :draft, customer:, issuing_date: DateTime.parse("21 Jun 2022").to_date, organization:)
        end

        before do
          invoice_to_be_finalized
          invoice_to_not_be_finalized
        end

        it "triggers async updates grace_period of invoices on default billing entity" do
          current_date = DateTime.parse("22 Jun 2022")
          old_invoice_grace_period = organization.invoice_grace_period

          travel_to(current_date) do
            result = update_service.call

            expect(result.organization.invoice_grace_period).to eq(2)
            expect(result.organization.default_billing_entity.invoice_grace_period).to eq(2)
            expect(Invoices::UpdateAllInvoiceIssuingDateFromBillingEntityJob)
              .to have_been_enqueued
              .with(
                organization.default_billing_entity,
                subscription_invoice_issuing_date_anchor: "next_period_start",
                subscription_invoice_issuing_date_adjustment: "align_with_finalization_date",
                invoice_grace_period: old_invoice_grace_period
              )
          end
        end
      end

      # Despite we do not use net_payment_term from org anymore, we need this test to ensure that update on billing_entity is
      # triggered and correctly handled
      # TODO: delete when cleaning up org from billing-entity specific data
      context "when updating net_payment_term" do
        let(:customer) { create(:customer, organization:) }

        let(:draft_invoice) do
          create(:invoice, status: :draft, customer:, created_at: DateTime.parse("19 Jun 2022"), organization:)
        end

        let(:params) do
          {
            net_payment_term: 2
          }
        end

        before do
          draft_invoice
          allow(BillingEntities::UpdateInvoicePaymentDueDateService).to receive(:call).and_call_original
        end

        it "updates the corresponding draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            result = update_service.call
            expect(result).to be_success

            expect(result.organization.net_payment_term).to eq(2)
            expect(BillingEntities::UpdateInvoicePaymentDueDateService).to have_received(:call).with(billing_entity: organization.default_billing_entity, net_payment_term: 2)
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

      it "updates the organization with logo" do
        result = update_service.call
        expect(result.organization.logo.blob).not_to be_nil
      end
    end

    context "with validation errors" do
      let(:country) { "---" }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:country]).to eq(["not_a_valid_country_code"])
      end
    end

    context "with eu tax management" do
      context "with org within the EU" do
        let(:params) { {eu_tax_management: true, country: "fr"} }

        before do
          allow(Taxes::AutoGenerateService).to receive(:call)
        end

        it "calls the taxes auto generate service" do
          result = update_service.call

          expect(result).to be_success
          expect(result.organization.eu_tax_management).to eq(true)
          expect(Taxes::AutoGenerateService).to have_received(:call).with(organization:).once
        end
      end

      context "with org outside the EU" do
        let(:params) { {eu_tax_management: true, country: "us"} }

        before do
          allow(Taxes::AutoGenerateService).to receive(:call)
        end

        it "does not call the taxes auto generate service" do
          result = update_service.call

          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({eu_tax_management: ["org_must_be_in_eu"]})
          expect(organization.reload.eu_tax_management).to eq(false)
          expect(Taxes::AutoGenerateService).not_to have_received(:call)
        end
      end

      context "with org is outside the EU but feature is already enabled" do
        let(:params) { {eu_tax_management: false} }

        before do
          organization.country = "us"
          organization.eu_tax_management = true
          allow(Taxes::AutoGenerateService).to receive(:call)
        end

        it "can disable eu_tax_management" do
          result = update_service.call

          expect(result).to be_success
          expect(result.organization.eu_tax_management).to eq(false)
          expect(Taxes::AutoGenerateService).not_to have_received(:call)
        end
      end
    end

    context "when organization does not have active billing_entities" do
      it "returns an error and does not update the organization" do
        organization.default_billing_entity.discard!
        organization.reload
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("billing_entity_not_found")
        expect(organization.reload.legal_name).not_to eq("Foobar")
        expect(organization.reload.legal_number).not_to eq("1234")
      end
    end

    context "when updating organization's document_numbering" do
      context "when updating to per_organization" do
        let(:params) { {document_numbering: "per_organization"} }

        it "updates the organization numbering to per_organization and default billing_entity to per_entity" do
          result = update_service.call

          expect(result.organization.document_numbering).to eq("per_organization")
          expect(result.organization.default_billing_entity.document_numbering).to eq("per_billing_entity")
        end
      end

      context "when updating to not existing value" do
        let(:params) { {document_numbering: "not_existing_document_numbering"} }

        it "returns an error" do
          result = update_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:document_numbering]).to eq(["value_is_invalid"])
        end
      end
    end

    context "when authentication_methods change" do
      subject { described_class.new(organization:, params:, user:) }

      let(:params) { {authentication_methods: ["email_password", "okta"]} }
      let(:user) { create(:user) }
      let(:additions) { ["okta"] }
      let(:deletions) { ["google_oauth"] }

      before { create(:membership, organization:, roles: %i[admin], user:) }

      it "delivers a email notification" do
        expect { subject.call }.to have_enqueued_mail(OrganizationMailer, :authentication_methods_updated)
          .with(params: {organization:, user:, additions:, deletions:}, args: [])
      end
    end
  end
end
