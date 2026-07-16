# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::RefreshDraftService do
  subject(:refresh_service) { described_class.new(invoice:) }

  describe "#call" do
    let(:status) { :draft }
    let(:invoice) do
      create(
        :invoice,
        status:,
        organization:,
        customer:,
        taxes_amount_cents: 10,
        total_amount_cents: 1000110010,
        taxes_rate: 30,
        fees_amount_cents: 2600,
        sub_total_excluding_taxes_amount_cents: 9900090,
        sub_total_including_taxes_amount_cents: 9900100,
        progressive_billing_credit_amount_cents: 1239000
      )
    end

    let(:started_at) { 1.month.ago.beginning_of_month }
    let(:customer) { create(:customer) }
    let(:organization) { customer.organization }
    let(:billing_entity) { customer.billing_entity }

    let(:subscription) do
      create(
        :subscription,
        customer:,
        organization:,
        subscription_at: started_at,
        started_at:,
        created_at: started_at
      )
    end

    let(:invoice_subscription) { create(:invoice_subscription, invoice:, subscription:, recurring: true) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 15) }

    before do
      invoice_subscription
      tax
      allow(Invoices::CalculateFeesService).to receive(:call).and_call_original
    end

    [
      :one_off,
      :add_on,
      :credit,
      :advance_charges,
      :progressive_billing
    ].each do |invoice_type|
      context "when invoice is #{invoice_type}" do
        let(:invoice) { create(:invoice, :draft, organization:, customer:, invoice_type:) }

        it "returns a forbidden failure" do
          result = refresh_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
        end
      end
    end

    context "when invoice is ready to be finalized" do
      let(:invoice) do
        create(:invoice, status:, organization:, customer:, ready_to_be_refreshed: true)
      end

      it "updates ready_to_be_refreshed to false" do
        expect { refresh_service.call }.to change(invoice, :ready_to_be_refreshed).to(false)
      end
    end

    context "when invoice is finalized" do
      let(:status) { :finalized }

      it "does not refresh it" do
        result = refresh_service.call
        expect(Invoices::CalculateFeesService).not_to have_received(:call)
        expect(result).to be_success
      end
    end

    context "when refreshing upgrading invoice" do
      let(:invoice2) do
        create(:invoice, status:, organization:, customer:)
      end
      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          invoice:,
          subscription:,
          recurring: false,
          invoicing_reason: "subscription_terminating"
        )
      end
      let(:invoice_subscription2) do
        create(
          :invoice_subscription,
          invoice:,
          subscription: subscription2,
          recurring: false,
          invoicing_reason: "subscription_starting"
        )
      end
      let(:invoice_subscription3) do
        create(
          :invoice_subscription,
          invoice: invoice2,
          subscription: subscription2,
          recurring: false,
          invoicing_reason: "subscription_terminating"
        )
      end
      let(:subscription) do
        create(
          :subscription,
          customer:,
          organization:,
          subscription_at: started_at - 1.month,
          started_at: started_at - 1.month,
          created_at: started_at - 1.month,
          terminated_at: started_at,
          status: :terminated
        )
      end
      let(:subscription2) do
        create(
          :subscription,
          customer:,
          organization:,
          subscription_at: started_at,
          started_at:,
          created_at: started_at,
          previous_subscription_id: subscription.id
        )
      end

      before do
        invoice_subscription2
        invoice_subscription3

        subscription2.mark_as_terminated!

        allow(Invoices::CalculateFeesService).to receive(:call).and_return(BaseService::Result.new)

        invoice.update!(created_at: started_at)
      end

      it "correctly creates invoice_subscriptions without duplicating invoicing reason" do
        refresh_service.call

        expect(invoice.reload.invoice_subscriptions.pluck(:invoicing_reason))
          .to match_array(%w[subscription_terminating subscription_starting])
      end
    end

    it "regenerates fees" do
      fee = create(:fee, invoice:)
      create(:standard_charge, plan: subscription.plan, charge_model: "standard")

      expect { refresh_service.call }
        .to change { invoice.fees.pluck(:id).include?(fee.id) }.from(true).to(false)
        .and change { invoice.fees.pluck(:created_at).uniq }.to([invoice.created_at])

      expect(invoice.invoice_subscriptions.first.recurring).to be_truthy
    end

    it "assigns credit notes to new created fee" do
      credit_note = create(:credit_note, invoice:)
      fee = create(:fee, invoice:, subscription:)
      create(:credit_note_item, credit_note:, fee:)

      expect { refresh_service.call }.to change { credit_note.reload.items.pluck(:fee_id) }
    end

    it "updates taxes_rate" do
      expect { refresh_service.call }
        .to change { invoice.reload.taxes_rate }.from(30.0).to(15)
    end

    it "recalculates progressive billing amount" do
      expect { refresh_service.call }
        .to change { invoice.reload.progressive_billing_credit_amount_cents }.from(1239000).to(0)
    end

    it_behaves_like "applies invoice_custom_sections" do
      let(:service_call) { refresh_service.call }
    end

    context "when there is a tax_integration set up" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
      let(:charge) { create(:standard_charge, plan: subscription.plan, charge_model: "standard") }

      before do
        integration_customer
        charge
      end

      context "when taxes are unknown" do
        it "regenerates fees" do
          expect { refresh_service.call }.to change { invoice.fees.count }.from(0).to(1)
        end

        it "sets correct tax status" do
          refresh_service.call

          expect(invoice.reload.tax_status).to eq("pending")
        end

        it "resets invoice values to calculatable before the error" do
          expect { refresh_service.call }.to change(invoice.reload, :taxes_amount_cents).from(10).to(0)
            .and change(invoice, :total_amount_cents).from(1000110010).to(0)
            .and change(invoice, :taxes_rate).from(30.0).to(0)
            .and change(invoice, :fees_amount_cents).from(2600).to(100)
            .and change(invoice, :sub_total_excluding_taxes_amount_cents).from(9900090).to(100)
            .and change(invoice, :sub_total_including_taxes_amount_cents).from(9900100).to(0)
        end
      end
    end

    context "when invoice has other applied invoice_custom_sections" do
      let(:invoice_custom_sections) { create_list(:invoice_custom_section, 4, organization: organization) }
      let(:applied_invoice_custom_sections) { create_list(:applied_invoice_custom_section, 2, invoice: invoice) }

      before do
        applied_invoice_custom_sections
        create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: invoice_custom_sections[0])
        create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: invoice_custom_sections[1])
        create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: invoice_custom_sections[2])
      end

      it "creates new applied_invoice_custom_sections" do
        expect { refresh_service.call }.to change { invoice.reload.applied_invoice_custom_sections.count }.from(2).to(3)
        expect(invoice.applied_invoice_custom_sections.map(&:code)).to match_array(customer.selected_invoice_custom_sections.map(&:code))
      end
    end

    it "flags lifetime usage for refresh" do
      create(:usage_threshold, plan: subscription.plan)

      refresh_service.call

      expect(subscription.reload.lifetime_usage.recalculate_invoiced_usage).to be(true)
    end
  end
end
