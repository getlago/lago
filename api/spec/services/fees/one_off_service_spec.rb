# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::OneOffService do
  subject(:one_off_service) do
    described_class.new(invoice:, fees:)
  end

  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:billing_entity) { create(:billing_entity) }
  let(:organization) { billing_entity.organization }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, billing_entity:) }
  let(:tax2) { create(:tax, organization:, applied_to_organization: false) }
  let(:add_on_first) { create(:add_on, organization:) }
  let(:add_on_second) { create(:add_on, amount_cents: 400, organization:) }
  let(:current_time) { DateTime.new(2023, 7, 19, 12, 12) }
  let(:fees) do
    [
      {
        add_on_code: add_on_first.code,
        unit_amount_cents: 1200,
        units: 2,
        description: "desc-123",
        tax_codes: [tax2.code]
      },
      {
        add_on_code: add_on_second.code
      }
    ]
  end

  before { tax }

  describe "create" do
    before { CurrentContext.source = "api" }

    it "creates fees" do
      travel_to(current_time) do
        result = one_off_service.call

        expect(result).to be_success

        first_fee = result.fees[0]
        second_fee = result.fees[1]

        expect(first_fee).to have_attributes(
          id: String,
          organization_id: organization.id,
          billing_entity_id: billing_entity.id,
          invoice_id: invoice.id,
          add_on_id: add_on_first.id,
          description: "desc-123",
          unit_amount_cents: 1200,
          precise_unit_amount: 12,
          units: 2,
          amount_cents: 2400,
          precise_amount_cents: 2400.0,
          amount_currency: "EUR",
          fee_type: "add_on",
          payment_status: "pending",
          properties: {
            "from_datetime" => current_time.to_time.utc.iso8601(3),
            "to_datetime" => current_time.to_time.utc.iso8601(3),
            "timestamp" => current_time
          }
        )
        expect(first_fee.taxes.map(&:code)).to contain_exactly(tax2.code)

        expect(second_fee).to have_attributes(
          id: String,
          organization_id: organization.id,
          billing_entity_id: billing_entity.id,
          invoice_id: invoice.id,
          add_on_id: add_on_second.id,
          description: add_on_second.description,
          unit_amount_cents: 400,
          precise_unit_amount: 4,
          units: 1,
          amount_cents: 400,
          precise_amount_cents: 400.0,
          amount_currency: "EUR",
          fee_type: "add_on",
          payment_status: "pending",
          properties: {
            "from_datetime" => current_time.to_time.utc.iso8601(3),
            "to_datetime" => current_time.to_time.utc.iso8601(3),
            "timestamp" => current_time
          }
        )
        expect(second_fee.applied_taxes).to be_empty
      end
    end

    context "with passed boundaries" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123",
            from_datetime: "2022-01-01T00:00:00Z",
            to_datetime: "2022-01-31T23:59:59.123Z",
            tax_codes: [tax2.code]
          }
        ]
      end

      it "creates fees" do
        travel_to(current_time) do
          result = one_off_service.call

          expect(result).to be_success

          first_fee = result.fees[0]

          expect(first_fee).to have_attributes(
            id: String,
            organization_id: organization.id,
            billing_entity_id: billing_entity.id,
            invoice_id: invoice.id,
            add_on_id: add_on_first.id,
            description: "desc-123",
            unit_amount_cents: 1200,
            precise_unit_amount: 12,
            units: 2,
            amount_cents: 2400,
            precise_amount_cents: 2400.0,
            amount_currency: "EUR",
            fee_type: "add_on",
            payment_status: "pending",
            properties: {
              "from_datetime" => "2022-01-01T00:00:00.000+00:00",
              "to_datetime" => "2022-01-31T23:59:59.123+00:00",
              "timestamp" => current_time
            }
          )
          expect(first_fee.taxes.map(&:code)).to contain_exactly(tax2.code)
        end
      end
    end

    context "when add_on_code is invalid" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123"
          },
          {
            add_on_code: "invalid"
          }
        ]
      end

      it "does not create an invalid fee" do
        one_off_service.call

        expect(Fee.find_by(description: add_on_second.description)).to be_nil
      end
    end

    context "when boundaries have invalid values" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123",
            from_datetime: "2022-05-01T00:00:00Z",
            to_datetime: "2022-01-31T23:59:59Z",
            tax_codes: [tax2.code]
          }
        ]
      end

      it "does not create an invalid fee" do
        one_off_service.call

        expect(Fee.find_by(description: add_on_first.description)).to be_nil
      end

      it "returns validation failure" do
        result = one_off_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:boundaries]).to include("values_are_invalid")
      end
    end

    context "when one boundary has invalid format" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123",
            from_datetime: "2022-01-01T00:00:00Z",
            to_datetime: "invalid",
            tax_codes: [tax2.code]
          }
        ]
      end

      it "does not create an invalid fee" do
        one_off_service.call

        expect(Fee.find_by(description: add_on_first.description)).to be_nil
      end

      it "returns validation failure" do
        result = one_off_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:boundaries]).to include("values_are_invalid")
      end
    end

    context "when one boundary raises a bare ArgumentError while parsing" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123",
            from_datetime: "1" * 129,
            to_datetime: "2022-01-31T23:59:59Z",
            tax_codes: [tax2.code]
          }
        ]
      end

      it "returns validation failure" do
        result = one_off_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:boundaries]).to include("values_are_invalid")
      end
    end

    context "when one boundary is in ISO8601 week-date format" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123",
            from_datetime: "2022-W04-1",
            to_datetime: "2022-01-31T23:59:59Z",
            tax_codes: [tax2.code]
          }
        ]
      end

      it "returns validation failure" do
        result = one_off_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:boundaries]).to include("values_are_invalid")
      end
    end

    context "when one boundary is missing" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123",
            from_datetime: "2022-01-01T00:00:00Z",
            tax_codes: [tax2.code]
          }
        ]
      end

      it "does not create an invalid fee" do
        one_off_service.call

        expect(Fee.find_by(description: add_on_first.description)).to be_nil
      end

      it "returns validation failure" do
        result = one_off_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:boundaries]).to include("values_are_invalid")
      end
    end

    context "when units is passed as string" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123",
            tax_codes: [tax2.code]
          }
        ]
      end

      it "creates fees" do
        result = one_off_service.call

        expect(result).to be_success

        first_fee = result.fees[0]

        expect(first_fee).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          add_on_id: add_on_first.id,
          description: "desc-123",
          unit_amount_cents: 1200,
          precise_unit_amount: 12,
          units: 2,
          amount_cents: 2400,
          precise_amount_cents: 2400.0,
          amount_currency: "EUR",
          fee_type: "add_on",
          payment_status: "pending"
        )
        expect(first_fee.taxes.map(&:code)).to contain_exactly(tax2.code)
      end
    end

    context "when customer has tax provider integration" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

      before { integration_customer }

      it "creates fees without taxes (deferred to provider)" do
        result = one_off_service.call

        expect(result).to be_success

        result.fees.each do |fee|
          expect(fee.applied_taxes).to be_empty
          expect(fee.taxes_amount_cents).to eq 0
        end
      end

      context "when explicit tax_codes are in the payload" do
        it "skips explicit taxes in favor of provider" do
          result = one_off_service.call

          first_fee = result.fees[0]
          expect(first_fee.applied_taxes).to be_empty
          expect(first_fee.taxes_amount_cents).to eq 0
        end
      end
    end
  end
end
