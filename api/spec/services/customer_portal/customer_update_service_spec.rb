# frozen_string_literal: true

require "rails_helper"

RSpec.describe CustomerPortal::CustomerUpdateService do
  subject(:result) { described_class.call(customer:, args: update_args) }

  let(:customer) { create :customer }

  let(:update_args) do
    {
      customer_type: "individual",
      document_locale: "es",
      name: "Updated customer name",
      firstname: "Updated customer firstname",
      lastname: "Updated customer lastname",
      legal_name: "Updated customer legal_name",
      tax_identification_number: "2246",
      email: "customer@email.test",
      address_line1: "Updated customer address line1",
      address_line2: "Updated customer address line2",
      zipcode: "Updated customer zipcode",
      city: "Updated customer city",
      state: "Updated customer state",
      country: "PT",
      shipping_address: {
        address_line1: "Updated customer shipping address line1",
        address_line2: "Updated customer shipping address line2",
        zipcode: "Updated customer shipping zipcode",
        city: "Updated customer shipping city",
        state: "Updated customer shipping state",
        country: "PT"
      }
    }
  end

  it "updates the customer" do
    expect(result).to be_success

    updated_customer = result.customer

    expect(updated_customer.customer_type).to eq(update_args[:customer_type])
    expect(updated_customer.name).to eq(update_args[:name])
    expect(updated_customer.firstname).to eq(update_args[:firstname])
    expect(updated_customer.lastname).to eq(update_args[:lastname])
    expect(updated_customer.legal_name).to eq(update_args[:legal_name])
    expect(updated_customer.tax_identification_number).to eq(update_args[:tax_identification_number])
    expect(updated_customer.email).to eq(update_args[:email])
    expect(updated_customer.document_locale).to eq(update_args[:document_locale])

    expect(updated_customer.address_line1).to eq(update_args[:address_line1])
    expect(updated_customer.address_line2).to eq(update_args[:address_line2])
    expect(updated_customer.zipcode).to eq(update_args[:zipcode])
    expect(updated_customer.city).to eq(update_args[:city])
    expect(updated_customer.state).to eq(update_args[:state])
    expect(updated_customer.country).to eq(update_args[:country])

    shipping_address = update_args[:shipping_address]
    expect(updated_customer.shipping_address_line1).to eq(shipping_address[:address_line1])
    expect(updated_customer.shipping_address_line2).to eq(shipping_address[:address_line2])
    expect(updated_customer.shipping_zipcode).to eq(shipping_address[:zipcode])
    expect(updated_customer.shipping_city).to eq(shipping_address[:city])
    expect(updated_customer.shipping_state).to eq(shipping_address[:state])
    expect(updated_customer.shipping_country).to eq(shipping_address[:country].upcase)
  end

  context "when partialy updating" do
    let(:update_args) do
      {
        name: "Updated customer name",
        shipping_address: {
          address_line1: "Updated customer shipping address line1"
        }
      }
    end

    it "updates only the updated args" do
      expect { result }.not_to change { customer.reload.email }

      expect(result).to be_success
      expect(result.customer.name).to eq(update_args[:name])
      expect(result.customer.shipping_address_line1).to eq(update_args[:shipping_address][:address_line1])
    end
  end

  context "with email containing unicode lookalike characters" do
    let(:update_args) do
      {
        email: "hello@something\u2013other.com"
      }
    end

    it "sanitizes the email before saving" do
      expect(result.customer.email).to eq("hello@something-other.com")
    end
  end

  context "when organization has eu tax management" do
    let(:organization) { customer.organization }
    let(:tax_code) { "lago_eu_fr_standard" }
    let(:eu_tax_result) { Customers::EuAutoTaxesService::Result.new }

    before do
      create(:tax, organization:, code: "lago_eu_fr_standard", rate: 20.0)
      organization.update!(eu_tax_management: true)

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

    context "when applying taxes fails" do
      let(:apply_taxes_result) do
        BaseService::Result.new.not_found_failure!(resource: "tax")
      end

      before do
        allow(Customers::ApplyTaxesService).to receive(:call).and_return(apply_taxes_result)
      end

      it "returns a service error" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("tax_not_found")
      end
    end
  end

  context "when customer is not found" do
    let(:customer) { nil }

    it "returns an error" do
      expect(result).not_to be_success
      expect(result.error.error_code).to eq("customer_not_found")
    end
  end

  context "with validation error" do
    let(:update_args) { {country: "invalid country code"} }

    it "returns an error" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages[:country]).to eq(["not_a_valid_country_code"])
    end
  end
end
