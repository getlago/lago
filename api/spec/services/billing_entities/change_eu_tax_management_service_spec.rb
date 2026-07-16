# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntities::ChangeEuTaxManagementService do
  subject(:service) { described_class.new(billing_entity:, eu_tax_management:) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:eu_tax_management) { true }

  describe "#call" do
    before do
      allow(Taxes::AutoGenerateService).to receive(:call)
    end

    context "when enabling EU tax management" do
      context "when billing entity is in the EU" do
        before do
          billing_entity.update!(country: "FR")
        end

        it "enables EU tax management" do
          result = service.call

          expect(result).to be_success
          expect(result.billing_entity.eu_tax_management).to eq(true)
        end

        it "calls the taxes auto generate service" do
          service.call

          expect(Taxes::AutoGenerateService).to have_received(:call).with(organization:)
        end
      end

      context "when billing entity is outside the EU" do
        before do
          billing_entity.update!(country: "US")
        end

        it "returns a validation failure" do
          result = service.call

          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({eu_tax_management: ["billing_entity_must_be_in_eu"]})
        end

        it "does not call the taxes auto generate service" do
          service.call

          expect(Taxes::AutoGenerateService).not_to have_received(:call)
        end
      end
    end

    context "when disabling EU tax management" do
      let(:eu_tax_management) { false }

      before do
        billing_entity.update!(eu_tax_management: true)
      end

      it "disables EU tax management" do
        result = service.call

        expect(result).to be_success
        expect(result.billing_entity.eu_tax_management).to eq(false)
      end

      it "does not call the taxes auto generate service" do
        service.call

        expect(Taxes::AutoGenerateService).not_to have_received(:call)
      end
    end

    context "when billing entity is not provided" do
      let(:billing_entity) { nil }

      it "returns a not found failure" do
        result = service.call

        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("billing_entity")
      end
    end
  end
end
