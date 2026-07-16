# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::UpdateInvoiceIssuingDateSettingsService do
  subject(:update_service) { described_class.new(customer:, params:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:params) do
    {
      billing_configuration: {
        subscription_invoice_issuing_date_anchor:,
        subscription_invoice_issuing_date_adjustment:
      },
      invoice_grace_period:
    }
  end

  let(:invoice_grace_period) { 2 }
  let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
  let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

  describe "#call" do
    let(:invoice_to_be_finalized) do
      create(:invoice, status: :draft, customer:, issuing_date: DateTime.parse("19 Jun 2022").to_date, expected_finalization_date: DateTime.parse("19 Jun 2022").to_date, organization:)
    end

    let(:invoice_to_not_be_finalized) do
      create(:invoice, status: :draft, customer:, issuing_date: DateTime.parse("21 Jun 2022").to_date, expected_finalization_date: DateTime.parse("21 Jun 2022").to_date, organization:)
    end

    before do
      invoice_to_be_finalized
      invoice_to_not_be_finalized
    end

    context "with premium feature", :premium do
      it "updates invoice issuing date settings on customer" do
        update_service.call

        customer.reload

        expect(customer.invoice_grace_period).to eq(2)
        expect(customer.subscription_invoice_issuing_date_anchor).to eq("next_period_start")
        expect(customer.subscription_invoice_issuing_date_adjustment).to eq("align_with_finalization_date")
      end

      it "finalizes corresponding draft invoices" do
        current_date = DateTime.parse("22 Jun 2022")

        travel_to(current_date) do
          result = update_service.call

          expect(result.customer.invoice_grace_period).to eq(2)
          expect(Invoices::FinalizeJob).not_to have_been_enqueued.with(invoice_to_not_be_finalized)
          expect(Invoices::FinalizeJob).to have_been_enqueued.with(invoice_to_be_finalized)
        end
      end

      it "updates issuing_date on draft invoices" do
        current_date = DateTime.parse("22 Jun 2022")

        travel_to(current_date) do
          expect { update_service.call }.to change { invoice_to_not_be_finalized.reload.issuing_date }
            .to(DateTime.parse("23 Jun 2022"))
            .and change { invoice_to_not_be_finalized.reload.payment_due_date }
            .to(DateTime.parse("23 Jun 2022"))
        end
      end

      context "when customer has net_payment_term" do
        let(:customer) { create(:customer, organization:, net_payment_term: 3) }

        it "updates issuing_date on draft invoices with payment term" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.to change { invoice_to_not_be_finalized.reload.issuing_date }
              .to(DateTime.parse("23 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.payment_due_date }
              .to(DateTime.parse("26 Jun 2022"))
          end
        end
      end

      context "when grace period is the same" do
        let(:invoice_grace_period) { customer.invoice_grace_period }
        let(:subscription_invoice_issuing_date_anchor) {}
        let(:subscription_invoice_issuing_date_adjustment) {}

        it "does not finalize any draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            update_service.call

            expect(Invoices::FinalizeJob).not_to have_been_enqueued
          end
        end

        it "does not update issuing_date on draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.not_to change { invoice_to_not_be_finalized.reload.issuing_date }
          end
        end
      end

      context "when clearing grace period" do
        before do
          customer.update(invoice_grace_period: 0)
        end

        let(:invoice_grace_period) { nil }

        it "clears the grace period" do
          expect { update_service.call }.to change(customer, :invoice_grace_period).from(0).to(nil)
        end
      end
    end

    context "without premium feature" do
      it "does not update invoice grace period on customer" do
        update_service.call

        customer.reload

        expect(customer.invoice_grace_period).to eq(nil)
        expect(customer.subscription_invoice_issuing_date_anchor).to eq("next_period_start")
        expect(customer.subscription_invoice_issuing_date_adjustment).to eq("align_with_finalization_date")
      end
    end

    context "with issuing date preferences", :premium do
      let(:recurring) { true }

      before do
        create(:invoice_subscription, invoice: invoice_to_be_finalized, organization:, recurring:)
        create(:invoice_subscription, invoice: invoice_to_not_be_finalized, organization:, recurring:)
      end

      context "with current_period_end + keep_anchor" do
        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
        let(:invoice_grace_period) { 2 }

        it "updates issuing_date on draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.to change { invoice_to_not_be_finalized.reload.issuing_date }
              .to(DateTime.parse("20 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.expected_finalization_date }
              .to(DateTime.parse("23 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.payment_due_date }
              .to(DateTime.parse("20 Jun 2022"))
          end
        end
      end

      context "with current_period_end + align_with_finalization_date" do
        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }
        let(:invoice_grace_period) { 2 }

        it "updates issuing_date on draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.to change { invoice_to_not_be_finalized.reload.issuing_date }
              .to(DateTime.parse("23 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.expected_finalization_date }
              .to(DateTime.parse("23 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.payment_due_date }
              .to(DateTime.parse("23 Jun 2022"))
          end
        end
      end

      context "with next_period_start + keep_anchor" do
        let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
        let(:invoice_grace_period) { 2 }

        it "updates issuing_date on draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.not_to change {
              [
                invoice_to_not_be_finalized.reload.issuing_date,
                invoice_to_not_be_finalized.reload.payment_due_date
              ]
            }

            expect(invoice_to_not_be_finalized.expected_finalization_date).to eq(DateTime.parse("23 Jun 2022"))
          end
        end
      end

      context "with next_period_start + align_with_finalization_date" do
        let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
        let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }
        let(:invoice_grace_period) { 2 }

        it "updates issuing_date on draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.to change { invoice_to_not_be_finalized.reload.issuing_date }
              .to(DateTime.parse("23 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.expected_finalization_date }
              .to(DateTime.parse("23 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.payment_due_date }
              .to(DateTime.parse("23 Jun 2022"))
          end
        end
      end

      context "with innoice_grace_period set up" do
        let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }

        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
        let(:invoice_grace_period) { 2 }

        it "updates issuing_date on draft invoices" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.to change { invoice_to_not_be_finalized.reload.issuing_date }
              .to(DateTime.parse("17 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.expected_finalization_date }
              .to(DateTime.parse("20 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.payment_due_date }
              .to(DateTime.parse("17 Jun 2022"))
          end
        end
      end

      context "with no preferences set on the customer level" do
        let(:billing_entity) do
          create(
            :billing_entity,
            subscription_invoice_issuing_date_anchor: "next_period_start",
            subscription_invoice_issuing_date_adjustment: "keep_anchor",
            invoice_grace_period: 3
          )
        end

        let(:customer) do
          create(
            :customer,
            organization:,
            billing_entity:,
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "align_with_finalization_date",
            invoice_grace_period: 2
          )
        end

        let(:subscription_invoice_issuing_date_anchor) {}
        let(:subscription_invoice_issuing_date_adjustment) {}
        let(:invoice_grace_period) {}

        it "updates issuing_date on draft invoices based on billing entity settings" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.to change { invoice_to_not_be_finalized.reload.issuing_date }
              .to(DateTime.parse("19 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.expected_finalization_date }
              .to(DateTime.parse("22 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.payment_due_date }
              .to(DateTime.parse("19 Jun 2022"))
          end
        end
      end

      context "when invoice is not recurring" do
        let(:recurring) { false }

        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
        let(:invoice_grace_period) { 2 }

        it "ignores all issuing date preferences" do
          current_date = DateTime.parse("22 Jun 2022")

          travel_to(current_date) do
            expect { update_service.call }.to change { invoice_to_not_be_finalized.reload.issuing_date }
              .to(DateTime.parse("23 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.expected_finalization_date }
              .to(DateTime.parse("23 Jun 2022"))
              .and change { invoice_to_not_be_finalized.reload.payment_due_date }
              .to(DateTime.parse("23 Jun 2022"))
          end
        end
      end
    end
  end
end
