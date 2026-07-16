# frozen_string_literal: true

require "rails_helper"

RSpec.describe Taxes::DestroyService do
  subject(:destroy_service) { described_class.new(tax:) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:) }
  let(:customer) { create(:customer, organization:) }

  describe "#call" do
    before { tax }

    it "destroys the tax" do
      expect { destroy_service.call }.to change(Tax, :count).by(-1)
    end

    it "marks invoices as ready to be refreshed" do
      draft_invoice = create(:invoice, :draft, organization:, customer:)

      expect { destroy_service.call }.to change { draft_invoice.reload.ready_to_be_refreshed }.to(true)
    end

    it "does not remove the other tax from the default billing entity" do
      expect { destroy_service.call }.to change { billing_entity.applied_taxes.count }.by(-1)
    end

    it "hard-deletes applicable join records and keeps non-draft invoice/fee taxes" do
      # Associations that must be removed on discard
      customer = create(:customer, organization:)
      customer_tax = create(:customer_applied_tax, customer:, tax:)

      # billing_entity = tax.organization.default_billing_entity
      billing_entity_tax = tax.billing_entities_taxes.sole
      billing_entity2 = create(:billing_entity, organization:)
      billing_entity_tax2 = create(:billing_entity_applied_tax, billing_entity: billing_entity2, tax:)
      billing_entity3 = create(:billing_entity, organization:)
      billing_entity_tax3 = create(:billing_entity_applied_tax, billing_entity: billing_entity3, tax: create(:tax))

      add_on = create(:add_on, organization:)
      add_on_tax = create(:add_on_applied_tax, add_on:, tax:)

      plan = create(:plan, organization:)
      plan_tax = create(:plan_applied_tax, plan:, tax:)

      charge = create(:standard_charge, organization:)
      charge_tax = create(:charge_applied_tax, charge:, tax:)

      commitment = create(:commitment, organization:)
      commitment_tax = create(:commitment_applied_tax, commitment:, tax:)

      fixed_charge = create(:fixed_charge, organization:)
      fixed_charge_tax = create(:fixed_charge_applied_tax, fixed_charge:, tax:)

      credit_note = create(:credit_note, organization:)
      credit_note_tax = create(:credit_note_applied_tax, credit_note:, tax:)

      # Invoices and fees: draft should be removed, finalized should remain
      finalized_invoice = create(:invoice, status: :finalized)
      finalized_invoice_tax = create(:invoice_applied_tax, invoice: finalized_invoice, tax:)
      finalized_fee = create(:fee, invoice: finalized_invoice)
      finalized_fee_tax = create(:fee_applied_tax, fee: finalized_fee, tax:)

      draft_invoice = create(:invoice, status: :draft)
      draft_invoice_tax = create(:invoice_applied_tax, invoice: draft_invoice, tax:)
      draft_fee = create(:fee, invoice: draft_invoice)
      draft_fee_tax = create(:fee_applied_tax, fee: draft_fee, tax:)

      expect { destroy_service.call }.to change { tax.reload.discarded? }.from(false).to(true)

      # join tables removed
      expect { customer_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { billing_entity_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { billing_entity_tax2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { add_on_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { plan_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { charge_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { commitment_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { fixed_charge_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { credit_note_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)

      # Draft invoice/fee taxes removed
      expect { draft_invoice_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { draft_fee_tax.reload }.to raise_error(ActiveRecord::RecordNotFound)

      # Finalized invoice/fee taxes kept
      expect(finalized_invoice.reload.applied_taxes).to include(finalized_invoice_tax)
      expect(finalized_fee.reload.applied_taxes).to include(finalized_fee_tax)

      # We ensure that we don't call the BillingEntities::RemoveTaxesService on all BillingEntities
      expect(billing_entity_tax3.reload).to be_persisted
    end

    context "when tax is not found" do
      let(:tax) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("tax_not_found")
      end
    end
  end
end
