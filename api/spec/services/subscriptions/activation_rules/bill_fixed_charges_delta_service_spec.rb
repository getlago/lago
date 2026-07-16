# frozen_string_literal: true

require "rails_helper"

describe Subscriptions::ActivationRules::BillFixedChargesDeltaService do
  subject(:result) { described_class.call(subscription:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:started_at) { Time.zone.parse("2026-03-05 10:00:00") }
  let(:current_time) { Time.zone.parse("2026-03-20 12:00:00") }
  let(:subscription) { create(:subscription, :incomplete, organization:, customer:, plan:, started_at:) }
  let(:service_result) { BaseService::Result.new }

  around { |test| travel_to(current_time) { test.run } }

  before do
    allow(Invoices::CreatePayInAdvanceFixedChargesService).to receive(:call).and_return(service_result)
  end

  describe "#call" do
    context "when the subscription has no pay-in-advance fixed charges" do
      before { create(:fixed_charge, plan:, organization:) }

      it "does not call Invoices::CreatePayInAdvanceFixedChargesService" do
        expect(result).to be_success
        expect(Invoices::CreatePayInAdvanceFixedChargesService).not_to have_received(:call)
      end
    end

    context "when the only event is the creation event at started_at + 1.second" do
      let(:fixed_charge) { create(:fixed_charge, :pay_in_advance, plan:, organization:) }

      before { create(:fixed_charge_event, subscription:, fixed_charge:, timestamp: started_at + 1.second) }

      it "does not call Invoices::CreatePayInAdvanceFixedChargesService" do
        expect(result).to be_success
        expect(Invoices::CreatePayInAdvanceFixedChargesService).not_to have_received(:call)
      end
    end

    context "when there are events during the incomplete window" do
      let(:fixed_charge) { create(:fixed_charge, :pay_in_advance, plan:, organization:) }
      let(:event_timestamp) { started_at + 10.days }

      before do
        create(:fixed_charge_event, subscription:, fixed_charge:, timestamp: started_at + 1.second)
        create(:fixed_charge_event, subscription:, fixed_charge:, timestamp: event_timestamp)
      end

      it "bills the delta timestamp" do
        expect(result).to be_success
        expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
          .with(subscription:, timestamp: event_timestamp.to_i).once
      end

      context "when several events share a timestamp" do
        let(:other_fixed_charge) { create(:fixed_charge, :pay_in_advance, plan:, organization:) }

        before { create(:fixed_charge_event, subscription:, fixed_charge: other_fixed_charge, timestamp: event_timestamp) }

        it "groups events by timestamp into a single billing call" do
          expect(result).to be_success
          expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
            .with(subscription:, timestamp: event_timestamp.to_i).once
        end
      end

      context "when there are two distinct plan-update timestamps" do
        let(:second_event_timestamp) { started_at + 12.days }

        before { create(:fixed_charge_event, subscription:, fixed_charge:, timestamp: second_event_timestamp) }

        it "bills each timestamp in chronological order" do
          expect(result).to be_success
          expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
            .with(subscription:, timestamp: event_timestamp.to_i).ordered
          expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
            .with(subscription:, timestamp: second_event_timestamp.to_i).ordered
        end
      end

      context "when the timestamp was already billed by a fixed-charge invoice" do
        before do
          invoice = create(:invoice, organization:, customer:)
          create(:invoice_subscription, subscription:, invoice:, invoicing_reason: :in_advance_charge, timestamp: Time.zone.at(event_timestamp.to_i))
          create(:fixed_charge_fee, invoice:)
        end

        it "skips the already billed timestamp" do
          expect(result).to be_success
          expect(Invoices::CreatePayInAdvanceFixedChargesService).not_to have_received(:call)
        end
      end

      context "when an in-advance usage invoice shares the timestamp" do
        before do
          invoice = create(:invoice, organization:, customer:)
          create(:invoice_subscription, subscription:, invoice:, invoicing_reason: :in_advance_charge, timestamp: Time.zone.at(event_timestamp.to_i))
          create(:charge_fee, invoice:)
        end

        it "bills the timestamp" do
          expect(result).to be_success
          expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
            .with(subscription:, timestamp: event_timestamp.to_i).once
        end
      end

      context "when a timestamp fails with a tax error" do
        let(:second_event_timestamp) { started_at + 12.days }
        let(:tax_error_result) { BaseService::Result.new.validation_failure!(errors: {tax_error: ["taxDateTooFarInFuture"]}) }

        before do
          create(:fixed_charge_event, subscription:, fixed_charge:, timestamp: second_event_timestamp)
          allow(Invoices::CreatePayInAdvanceFixedChargesService).to receive(:call)
            .and_return(tax_error_result, service_result)
        end

        it "continues with the next timestamp" do
          expect(result).to be_success
          expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call).twice
        end
      end

      context "when a timestamp fails with a non-tax error" do
        let(:failed_result) { BaseService::Result.new.single_validation_failure!(error_code: "error") }

        before do
          allow(Invoices::CreatePayInAdvanceFixedChargesService).to receive(:call).and_return(failed_result)
        end

        it "raises the error" do
          expect { result }.to raise_error(BaseService::FailedResult)
        end
      end
    end

    context "when a scheduled event lands after the first period end" do
      let(:current_time) { Time.zone.parse("2026-04-03 12:00:00") }
      let(:fixed_charge) { create(:fixed_charge, :pay_in_advance, plan:, organization:) }
      let(:first_period_end) { Time.zone.parse("2026-03-31").end_of_day }

      before do
        create(:fixed_charge_event, subscription:, fixed_charge:, timestamp: started_at + 1.second)
        create(:fixed_charge_event, subscription:, fixed_charge:, timestamp: first_period_end + 1.second)
      end

      it "does not bill the scheduled timestamp" do
        expect(result).to be_success
        expect(Invoices::CreatePayInAdvanceFixedChargesService).not_to have_received(:call)
      end

      context "with an immediate event inside the first period" do
        let(:event_timestamp) { started_at + 10.days }

        before { create(:fixed_charge_event, subscription:, fixed_charge:, timestamp: event_timestamp) }

        it "bills only the immediate timestamp" do
          expect(result).to be_success
          expect(Invoices::CreatePayInAdvanceFixedChargesService).to have_received(:call)
            .with(subscription:, timestamp: event_timestamp.to_i).once
        end
      end
    end
  end
end
