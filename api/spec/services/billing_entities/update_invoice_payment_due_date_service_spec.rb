# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntities::UpdateInvoicePaymentDueDateService do
  subject(:update_service) { described_class.new(billing_entity:, net_payment_term:) }

  let(:billing_entity) { create(:billing_entity) }
  let(:organization) { billing_entity.organization }
  let(:customer) { create(:customer, organization:, net_payment_term: customer_net_payment_term) }
  let(:customer_net_payment_term) { nil }
  let(:net_payment_term) { 30 }

  describe "#call" do
    let(:draft_invoice) do
      create(:invoice, status: :draft, customer:, organization:, issuing_date: DateTime.parse("21 Jun 2022"), billing_entity:)
    end
    let(:finalized_invoice) { create(:invoice, status: :finalized, customer:, organization:, issuing_date: DateTime.parse("21 Jun 2022"), billing_entity:) }

    before do
      draft_invoice
      finalized_invoice
    end

    it "updates invoice payment_due_date" do
      result = update_service.call
      expect(result.billing_entity.net_payment_term).to eq(30)
    end

    it "updates only draft invoice payment_due_date" do
      expect { update_service.call }.to change { draft_invoice.reload.payment_due_date }
        .from(DateTime.parse("21 Jun 2022"))
        .to(DateTime.parse("21 Jun 2022") + net_payment_term.days)
        .and not_change(finalized_invoice.reload, :payment_due_date)
    end

    it "updates draft invoice net_payment_date" do
      expect { update_service.call }.to change { draft_invoice.reload.net_payment_term }
        .from(0).to(30).and not_change { finalized_invoice.reload.net_payment_term }
    end

    context "when customer has their own net_payment_term" do
      let(:customer_net_payment_term) { 10 }

      it "doesn't update fields" do
        expect { update_service.call }.not_to change { draft_invoice.reload.payment_due_date }
        expect { update_service.call }.not_to change { draft_invoice.reload.net_payment_term }
      end
    end

    context "when drat invoice belongs to another billing entity" do
      let(:another_billing_entity) { create(:billing_entity) }
      let(:draft_invoice) do
        create(:invoice, status: :draft, customer:, organization:, issuing_date: DateTime.parse("21 Jun 2022"), billing_entity: another_billing_entity)
      end

      it "doesn't update draft invoice net_payment_term" do
        expect { update_service.call }.not_to change { draft_invoice.reload.net_payment_term }
      end

      it "doesn't update draft invoice payment_due_date" do
        expect { update_service.call }.not_to change { draft_invoice.reload.payment_due_date }
      end
    end
  end
end
