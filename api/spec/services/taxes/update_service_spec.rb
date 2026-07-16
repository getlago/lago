# frozen_string_literal: true

require "rails_helper"

RSpec.describe Taxes::UpdateService do
  subject(:update_service) { described_class.new(tax:, params:) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:) }

  let(:customer) { create(:customer, organization:) }

  describe "#call" do
    before { tax }

    let(:params) do
      {
        code: "updated code",
        rate: 15.0,
        description: "updated desc"
      }
    end

    it "updates the tax" do
      result = update_service.call

      expect(result).to be_success
      expect(result.tax).to have_attributes(
        name: tax.name,
        code: params[:code],
        rate: params[:rate],
        description: params[:description]
      )
    end

    it "returns tax in the result" do
      result = update_service.call
      expect(result.tax).to be_a(Tax)
    end

    context "when applied_to_organization is updated to false" do
      let(:params) do
        {applied_to_organization: false}
      end

      it "marks invoices as ready to be refreshed" do
        draft_invoice = create(:invoice, :draft, organization:, customer:)

        expect { update_service.call }.to change { draft_invoice.reload.ready_to_be_refreshed }.to(true)
      end

      it "removes the applied tax from billing_entity" do
        expect { update_service.call }.to change { billing_entity.applied_taxes.count }.by(-1)
      end

      context "when organization has multiple billing entities" do
        let(:billing_entity2) { create(:billing_entity, organization:) }
        let(:applied_tax2) { create(:billing_entity_applied_tax, billing_entity: billing_entity2, tax:) }

        before { applied_tax2 }

        it "removes the applied tax only from the default billing entity" do
          expect { update_service.call }.not_to change { billing_entity2.applied_taxes.count }
          expect(billing_entity.reload.applied_taxes.count).to be(0)
        end
      end
    end

    context "when applied_to_organization is updated to true" do
      let(:tax) { create(:tax, organization:, applied_to_organization: false) }
      let(:params) do
        {applied_to_organization: true}
      end

      it "marks invoices as ready to be refreshed" do
        draft_invoice = create(:invoice, :draft, organization:, customer:)

        expect { update_service.call }.to change { draft_invoice.reload.ready_to_be_refreshed }.to(true)
      end

      it "creates applied tax for the default billing entity" do
        expect { update_service.call }.to change { billing_entity.applied_taxes.count }.by(1)
        expect(billing_entity.applied_taxes.last.tax).to eq(tax)
      end

      context "when default billing entity already have this tax applied" do
        let(:applied_tax) { create(:billing_entity_applied_tax, billing_entity:, tax:) }

        before { applied_tax }

        it "does not create a new applied tax" do
          expect { update_service.call }.not_to change { billing_entity.applied_taxes.count }
        end
      end

      context "when organization has multiple billing entities" do
        let(:billing_entity2) { create(:billing_entity, organization:) }

        before { billing_entity2 }

        it "creates applied tax only for the default billing entity" do
          expect { update_service.call }.to change { billing_entity.applied_taxes.count }.by(1).and not_change { billing_entity2.applied_taxes.count }
          expect(billing_entity.applied_taxes.last.tax).to eq(tax)
          expect(billing_entity2.applied_taxes).to be_empty
        end
      end
    end

    it "marks invoices as ready to be refreshed" do
      draft_invoice = create(:invoice, :draft, organization:, customer:)

      expect { update_service.call }.to change { draft_invoice.reload.ready_to_be_refreshed }.to(true)
    end

    context "when tax is not found" do
      let(:tax) { nil }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("tax_not_found")
      end
    end

    context "with validation error" do
      let(:params) do
        {
          id: tax.id,
          name: nil,
          code: "code",
          amount_cents: 100,
          amount_currency: "EUR"
        }
      end

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:name]).to eq(["value_is_mandatory"])
      end
    end
  end
end
