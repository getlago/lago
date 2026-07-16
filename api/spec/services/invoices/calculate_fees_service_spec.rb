# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::CalculateFeesService do
  subject(:invoice_service) do
    described_class.new(
      invoice:,
      recurring:,
      context:
    )
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:recurring) { false }
  let(:context) { nil }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      currency: "EUR",
      issuing_date: Time.zone.at(timestamp).to_date,
      customer:
    )
  end

  let(:subscription) do
    create(
      :subscription,
      organization:,
      plan:,
      customer:,
      billing_time:,
      subscription_at: started_at,
      started_at:,
      created_at:,
      status:,
      terminated_at:
    )
  end

  let(:date_service) do
    Subscriptions::DatesService.new_instance(
      subscription,
      Time.zone.at(timestamp),
      current_usage: subscription.terminated? && subscription.upgraded?
    )
  end

  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      subscription:,
      invoice:,
      timestamp:,
      from_datetime: date_service.from_datetime,
      to_datetime: date_service.to_datetime,
      charges_from_datetime: date_service.charges_from_datetime,
      charges_to_datetime: date_service.charges_to_datetime,
      fixed_charges_from_datetime: date_service.fixed_charges_from_datetime,
      fixed_charges_to_datetime: date_service.fixed_charges_to_datetime
    )
  end

  let(:invoice_subscriptions) { [invoice_subscription] }

  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
  let(:add_on) { create(:add_on) }
  let(:timestamp) { Time.zone.now.beginning_of_month }
  let(:started_at) { Time.zone.now - 2.years }
  let(:created_at) { started_at }
  let(:terminated_at) { nil }
  let(:status) { :active }

  let(:plan) { create(:plan, organization:, interval:, pay_in_advance:, trial_period:) }
  let(:pay_in_advance) { false }
  let(:billing_time) { :calendar }
  let(:interval) { "monthly" }
  let(:trial_period) { 0 }

  let(:charge) do
    create(
      :standard_charge,
      plan: subscription.plan,
      charge_model: "standard",
      billable_metric:,
      properties: {amount: "1"}
    )
  end

  let(:event) do
    create(
      :event,
      organization: organization,
      subscription: subscription,
      code: billable_metric.code,
      timestamp: event_timestamp
    )
  end

  let(:event_timestamp) { [date_service.charges_to_datetime - 2.days, started_at].max }

  let(:fixed_charge) do
    create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "10"}, units: 10)
  end

  let(:fixed_charge_event) do
    create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: event_timestamp, units: 10, created_at: event_timestamp)
  end

  before do
    tax
    charge
    invoice_subscriptions
    event
    fixed_charge
    fixed_charge_event

    allow(SegmentTrackJob).to receive(:perform_later)
    allow(Invoices::Payments::CreateService).to receive(:call_async).and_call_original
    allow(Credits::ProgressiveBillingService).to receive(:call).and_call_original
  end

  describe "#call" do
    context "when subscription is billed on anniversary date" do
      let(:timestamp) { Time.zone.parse("07 Mar 2022") }
      let(:started_at) { Time.zone.parse("06 Jun 2021").to_date }
      let(:subscription_at) { started_at }
      let(:billing_time) { :anniversary }

      it "creates subscription, charge and fixed charge fees" do
        result = invoice_service.call

        expect(result).to be_success

        expect(invoice.subscriptions.first).to eq(subscription)
        expect(invoice.payment_status).to eq("pending")
        expect(invoice.fees.subscription.count).to eq(1)
        expect(invoice.fees.charge.count).to eq(1)
        expect(invoice.fees.fixed_charge.count).to eq(1)

        invoice_subscription = invoice.invoice_subscriptions.first
        expect(invoice_subscription).to have_attributes(
          to_datetime: match_datetime(Time.zone.parse("2022-03-05 23:59:59")),
          from_datetime: match_datetime(Time.zone.parse("2022-02-06 00:00:00"))
        )
      end

      it "calls the ProgressiveBillingService" do
        result = invoice_service.call
        expect(result).to be_success
        expect(Credits::ProgressiveBillingService).to have_received(:call).with(invoice:)
      end

      context "with adjusted fees existence query" do
        let(:adjusted_fee) do
          create(
            :adjusted_fee,
            invoice:,
            subscription:,
            charge:,
            fee_type: :charge,
            properties: {
              charges_from_datetime: date_service.charges_from_datetime,
              charges_to_datetime: date_service.charges_to_datetime
            }
          )
        end

        before do
          allow(AdjustedFee).to receive(:matching_charge_boundaries).and_call_original
          allow(Fees::ChargeService).to receive(:call!).and_call_original
        end

        context "when the invoice is a draft with an adjusted fee" do
          before do
            invoice.draft!
            adjusted_fee
          end

          it "queries AdjustedFee and applies the adjusted fee" do
            invoice_service.call

            expect(AdjustedFee).to have_received(:matching_charge_boundaries)
            expect(Fees::ChargeService).to have_received(:call!).with(hash_including(skip_adjusted_fees: false))
          end
        end

        context "when the invoice is a draft without an adjusted fee" do
          before { invoice.draft! }

          it "queries AdjustedFee only once and skips the per-charge lookup" do
            invoice_service.call

            expect(AdjustedFee).to have_received(:matching_charge_boundaries).once
            expect(Fees::ChargeService).to have_received(:call!).with(hash_including(skip_adjusted_fees: true))
          end
        end

        context "when finalizing the invoice" do
          let(:context) { :finalize }

          it "queries AdjustedFee" do
            invoice_service.call

            expect(AdjustedFee).to have_received(:matching_charge_boundaries)
          end
        end
      end

      context "when a progressive_billing invoice is present" do
        let(:progressive_invoice) do
          create(
            :invoice,
            :with_subscriptions,
            customer:,
            status: "finalized",
            invoice_type: :progressive_billing,
            subscriptions: [subscription],
            fees_amount_cents: 50,
            issuing_date: timestamp - 5.days,
            created_at: timestamp - 5.days
          )
        end

        let(:progressive_fee) do
          create(:charge_fee, amount_cents: 50, invoice: progressive_invoice)
        end

        let(:event) { nil }

        before do
          progressive_invoice
          progressive_fee
          progressive_invoice.invoice_subscriptions.first.update!(
            charges_from_datetime: progressive_invoice.issuing_date - 1.month,
            charges_to_datetime: progressive_invoice.issuing_date,
            timestamp: progressive_invoice.issuing_date
          )
        end

        it "creates a credit note for the amount that was billed too much" do
          expect { invoice_service.call }.to change(CreditNote, :count).by(1)

          credit_note = progressive_invoice.reload.credit_notes.sole
          expect(credit_note.credit_amount_cents).to eq(50)
        end
      end

      context "when there is tax provider integration" do
        let(:integration) { create(:anrok_integration, organization:) }
        let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

        before do
          integration_customer
        end

        it "returns tax unknown error and puts invoice in valid status" do
          result = invoice_service.call

          expect(result).not_to be_success
          expect(result.error.code).to eq("tax_error")
          expect(result.error.error_message).to eq("unknown taxes")

          expect(invoice.reload.status).to eq("pending")
          expect(invoice.reload.tax_status).to eq("pending")
          expect(invoice.reload.fees_amount_cents).to eq(10200)
          expect(invoice.reload.taxes_amount_cents).to eq(0)
          expect(invoice.reload.error_details.count).to eq(0)
        end

        context "when calculating fees for draft invoice" do
          let(:invoice) do
            create(
              :invoice,
              :draft,
              organization:,
              currency: "EUR",
              issuing_date: Time.zone.at(timestamp).to_date,
              customer: subscription.customer
            )
          end

          context "when no context is passed" do
            it "returns tax unknown error and puts invoice in valid status" do
              result = invoice_service.call

              expect(result).not_to be_success
              expect(result.error.code).to eq("tax_error")
              expect(result.error.error_message).to eq("unknown taxes")

              expect(invoice.reload.status).to eq("draft")
              expect(invoice.reload.tax_status).to eq("pending")
              expect(invoice.reload.fees_amount_cents).to eq(10200)
              expect(invoice.reload.taxes_amount_cents).to eq(0)
              expect(invoice.reload.error_details.count).to eq(0)
            end
          end

          context "when context is :finalize" do
            let(:context) { :finalize }

            it "returns tax unknown error and puts invoice in valid status" do
              result = invoice_service.call

              expect(result).not_to be_success
              expect(result.error.code).to eq("tax_error")
              expect(result.error.error_message).to eq("unknown taxes")

              expect(invoice.reload.status).to eq("pending")
              expect(invoice.reload.tax_status).to eq("pending")
              expect(invoice.reload.fees_amount_cents).to eq(10200)
              expect(invoice.reload.taxes_amount_cents).to eq(0)
              expect(invoice.reload.error_details.count).to eq(0)
            end
          end
        end
      end

      context "when charge is pay_in_advance, not recurring and invoiceable" do
        let(:charge) do
          create(
            :standard_charge,
            :pay_in_advance,
            plan: subscription.plan,
            organization:,
            charge_model: "standard",
            invoiceable: true
          )
        end

        it "does not create a charge fee" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.fees.charge.count).to eq(0)
        end
      end

      context "when charge is pay_in_advance, recurring and invoiceable" do
        let(:billable_metric) do
          create(:billable_metric, aggregation_type: "unique_count_agg", recurring: true, field_name: "item_id")
        end
        let(:charge) do
          create(
            :standard_charge,
            :pay_in_advance,
            plan: subscription.plan,
            organization:,
            charge_model: "standard",
            invoiceable: true,
            billable_metric:
          )
        end

        it "creates a charge fee", transaction: false do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.fees.charge.count).to eq(1)
        end
      end

      context "when charge is pay_in_advance, not recurring and not invoiceable" do
        let(:charge) do
          create(
            :standard_charge,
            :pay_in_advance,
            plan: subscription.plan,
            organization:,
            charge_model: "standard",
            invoiceable: false
          )
        end

        it "does not create a charge fee" do
          result = invoice_service.call

          expect(result).to be_success

          expect(Fee.charge.count).to eq(0)
        end
      end

      context "when charge is pay_in_advance, recurring and not invoiceable" do
        let(:billable_metric) do
          create(:billable_metric, organization:, aggregation_type: "unique_count_agg", recurring: true, field_name: "item_id")
        end
        let(:charge) do
          create(
            :standard_charge,
            :pay_in_advance,
            plan: subscription.plan,
            charge_model: "standard",
            invoiceable: false,
            billable_metric:
          )
        end

        it "creates a charge fee" do
          result = invoice_service.call

          expect(result).to be_success
          expect(Fee.charge.where(invoice_id: nil).count).to eq(1)
        end
      end

      # when pay_in_advance is true, the fixed charge fee is created, but with period of the next month
      context "when fixed charge is pay_in_advance" do
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "standard",
            pay_in_advance: true,
            properties: {amount: "10"}
          )
        end

        it "creates a fixed charge fee with period of the next month" do
          result = invoice_service.call

          expect(result).to be_success
          expect(invoice.fees.fixed_charge.count).to eq(1)
          fee_properties = invoice.fees.fixed_charge.first.properties
          expect(fee_properties["fixed_charges_from_datetime"]).to match_datetime(Time.parse("2022-03-06T00:00:00.000Z"))
          expect(fee_properties["fixed_charges_to_datetime"]).to match_datetime(Time.parse("2022-04-05T23:59:59.999Z"))
        end

        context "when subscription is terminated" do
          let(:status) { :terminated }
          let(:terminated_at) { timestamp - 1.day }

          it "does not create a fixed charge fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.fixed_charge.count).to eq(0)
          end
        end
      end

      context "when fixed charge is pay_in_arrears" do
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "standard",
            pay_in_advance: false,
            properties: {amount: "10"}
          )
        end

        it "creates a fixed charge fee with period of this month" do
          result = invoice_service.call

          expect(result).to be_success
          expect(invoice.fees.fixed_charge.count).to eq(1)
          fee_properties = invoice.fees.fixed_charge.first.properties
          expect(fee_properties["fixed_charges_from_datetime"]).to match_datetime(Time.parse("2022-02-06T00:00:00.000Z"))
          expect(fee_properties["fixed_charges_to_datetime"]).to match_datetime(Time.parse("2022-03-05T23:59:59.999Z"))
        end

        context "when subscription is terminated" do
          let(:status) { :terminated }
          let(:terminated_at) { timestamp - 1.day }

          it "does create a fixed charge fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.fixed_charge.count).to eq(1)
          end
        end
      end

      context "when there are multiple fixed charges" do
        context "when changing the subscription" do
          let(:add_on1) { create(:add_on, organization:) }
          let(:add_on2) { create(:add_on, organization:) }

          let(:old_plan) { create(:plan, organization:, interval:, pay_in_advance:, trial_period:) }
          let(:new_plan) { create(:plan, organization:, interval:, pay_in_advance:, trial_period:, amount_cents: 2000) }

          let(:old_fixed_charge_arrears) do
            create(
              :fixed_charge,
              plan: old_plan,
              add_on: add_on1,
              charge_model: "standard",
              pay_in_advance: false,
              properties: {amount: "10"}
            )
          end

          let(:new_fixed_charge_advance) do
            create(
              :fixed_charge,
              plan: new_plan,
              add_on: add_on1,
              charge_model: "standard",
              pay_in_advance: true,
              properties: {amount: "10"}
            )
          end

          let(:new_fixed_charge_arrears) do
            create(
              :fixed_charge,
              plan: new_plan,
              add_on: add_on2,
              charge_model: "standard",
              pay_in_advance: false,
              properties: {amount: "15"}
            )
          end

          let(:fixed_charge) do
            create(
              :fixed_charge,
              plan: subscription.plan,
              charge_model: "standard",
              pay_in_advance: true,
              properties: {amount: "10"},
              units: 1
            )
          end

          let(:old_subscription) do
            create(
              :subscription,
              plan: old_plan,
              organization:,
              customer:,
              billing_time:,
              subscription_at: started_at,
              started_at:,
              created_at:,
              status: :terminated,
              terminated_at: timestamp - 1.day
            )
          end

          let(:new_subscription) do
            create(
              :subscription,
              plan: new_plan,
              organization:,
              customer:,
              billing_time:,
              subscription_at: started_at,
              started_at: timestamp,
              created_at: timestamp,
              status: :active,
              previous_subscription: old_subscription
            )
          end

          let(:old_fixed_charge_arrears_event) do
            create(:fixed_charge_event, fixed_charge: old_fixed_charge_arrears, subscription: old_subscription, timestamp: event_timestamp, units: 10, created_at: event_timestamp)
          end

          let(:new_fixed_charge_advance_event) do
            create(:fixed_charge_event, fixed_charge: new_fixed_charge_advance, subscription: new_subscription, timestamp:, units: 1)
          end

          let(:new_fixed_charge_arrears_event) do
            create(:fixed_charge_event, fixed_charge: new_fixed_charge_arrears, subscription: new_subscription, timestamp:, units: 1)
          end

          before do
            old_fixed_charge_arrears_event
            new_fixed_charge_advance_event
            new_fixed_charge_arrears_event
          end

          # for now we'll just always create the fixed_charge fee. in the next PR we'll handle upgrade/downgrade/termination scenarios
          # for terminated subscription do not issue pay in advance fee, issue only pay in arrears fee
          context "when subscription is upgraded" do
            context "when passing old subscription in the service" do
              let(:subscription) { old_subscription }

              it "creates only fee for pay in arrears charges" do
                result = invoice_service.call

                expect(result).to be_success
                expect(subscription.fixed_charges.count).to eq(2)
                expect(invoice.fees.fixed_charge.count).to eq(1)
                expect(invoice.fees.fixed_charge.first.fixed_charge).to eq(old_fixed_charge_arrears)
              end
            end

            context "when passing new subscription in the service" do
              let(:subscription) { new_subscription }

              before do
                invoice_subscription[:invoicing_reason] = :subscription_starting
                invoice_subscription.save!
              end

              it "creates a fixed charge fee for the new subscription only for pay in advance charges" do
                result = invoice_service.call

                expect(result).to be_success
                expect(subscription.fixed_charges.count).to eq(3)
                expect(invoice.fees.fixed_charge.count).to eq(2)
                expect(invoice.fees.fixed_charge.map(&:fixed_charge)).to match_array([new_fixed_charge_advance, fixed_charge])
              end
            end
          end

          context "when subscriptions is downgraded" do
            let(:old_plan) { create(:plan, organization:, interval:, pay_in_advance:, trial_period:, amount_cents: 10000) }
            let(:new_plan) { create(:plan, organization:, interval:, pay_in_advance:, trial_period:, amount_cents: 2000) }

            context "when passing old subscription in the service" do
              let(:subscription) { old_subscription }

              it "creates a pay_in_arrears fee for the previous subscription" do
                result = invoice_service.call

                expect(result).to be_success
                expect(invoice.fees.fixed_charge.count).to eq(1)
                expect(invoice.fees.fixed_charge.first.fixed_charge).to eq(old_fixed_charge_arrears)
              end
            end

            context "when passing new subscription in the service" do
              let(:subscription) { new_subscription }
              let(:fixed_charge) do
                create(
                  :fixed_charge,
                  plan: new_plan,
                  charge_model: "standard",
                  pay_in_advance: false,
                  properties: {amount: "10"},
                  units: 1
                )
              end

              before do
                invoice_subscription.update!(invoicing_reason: :subscription_starting)
              end

              it "creates a fixed charge fee for the new subscription only for pay in advance charges" do
                result = invoice_service.call

                expect(result).to be_success
                expect(invoice.fees.fixed_charge.count).to eq(1)
                expect(invoice.fees.fixed_charge.map(&:fixed_charge)).to match_array([new_fixed_charge_advance])
              end
            end
          end
        end
      end
    end

    context "when billed for the first time" do
      let(:timestamp) { Time.zone.now.beginning_of_month }
      let(:started_at) { timestamp - 3.days }

      context "when plan has no other requirements" do
        it "creates subscription, charge and fixed charge fees" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)
          expect(invoice.fees.fixed_charge.count).to eq(1)
          expect(invoice.fees.commitment.count).to eq(0)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime((timestamp - 1.day).end_of_day),
            from_datetime: match_datetime(subscription.subscription_at.beginning_of_day)
          )
        end
      end

      context "when plan has minimum commitment" do
        let(:fixed_charge) do
          create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "0.001"}, units: 10)
        end

        before do
          create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
        end

        it "creates subscription, charge, fixed charge and commitment fees" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)
          expect(invoice.fees.fixed_charge.count).to eq(1)
          expect(invoice.fees.commitment.count).to eq(1)
        end
      end

      context "when plan has non invoiceable, recurring, pay in advance charge" do
        before do
          create(
            :standard_charge,
            :pay_in_advance,
            plan: subscription.plan,
            charge_model: "standard",
            invoiceable: false,
            billable_metric: create(:billable_metric, organization:, aggregation_type: "unique_count_agg", recurring: true, field_name: "item_id")
          )
        end

        it "creates subscription, charge and commitment fees" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.fees.charge.count).to eq(1)
          expect(Fee.where(invoice_id: nil).count).to eq(1)
        end
      end

      context "when plan has graduated fixed charge" do
        let(:fixed_charge) do
          create(
            :fixed_charge,
            :graduated,
            plan: subscription.plan,
            properties: {
              graduated_ranges: [
                {from_value: 0, to_value: 10, per_unit_amount: "5", flat_amount: "200"},
                {from_value: 11, to_value: nil, per_unit_amount: "1", flat_amount: "300"}
              ]
            },
            units: 15
          )
        end

        let(:fixed_charge_event) do
          create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: event_timestamp, units: 15)
        end

        it "creates subscription, charge and graduated fixed charge fees" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)
          expect(invoice.fees.fixed_charge.count).to eq(1)
          expect(invoice.fees.commitment.count).to eq(0)

          fixed_charge_fee = invoice.fees.fixed_charge.first
          expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge)
          expect(fixed_charge_fee.units).to eq(15)
          expect(fixed_charge_fee.amount_cents).to eq(20000 + 30000 + 10 * 500 + 5 * 100)
        end
      end

      context "when plan has volume fixed charge" do
        let(:fixed_charge) do
          create(
            :fixed_charge,
            :volume,
            plan: subscription.plan,
            properties: {
              volume_ranges: [
                {from_value: 0, to_value: 100, per_unit_amount: "2", flat_amount: "1"},
                {from_value: 101, to_value: nil, per_unit_amount: "1", flat_amount: "0"}
              ]
            }
          )
        end

        let(:fixed_charge_event) do
          create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: event_timestamp, units: 150)
        end

        it "creates subscription, charge and volume fixed charge fees" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)
          expect(invoice.fees.fixed_charge.count).to eq(1)
          expect(invoice.fees.commitment.count).to eq(0)

          fixed_charge_fee = invoice.fees.fixed_charge.first
          expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge)
          expect(fixed_charge_fee.units).to eq(150)
          expect(fixed_charge_fee.amount_cents).to eq(15000)
        end
      end

      context "when plan has prorated fixed charge" do
        let(:timestamp) { Time.zone.parse("01 Mar 2022") }
        let(:event_timestamp) { Time.zone.parse("14 Feb 2022") }
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "standard",
            prorated: true,
            properties: {amount: "10"}
          )
        end

        let(:fixed_charge_event) do
          create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: event_timestamp, units: 28, created_at: event_timestamp)
        end

        it "creates subscription, charge and prorated fixed charge fees" do
          result = invoice_service.call
          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.fixed_charge.count).to eq(1)
          expect(invoice.fees.commitment.count).to eq(0)

          fixed_charge_fee = invoice.fees.fixed_charge.first
          expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge)
          # total units on the event is 28
          expect(fixed_charge_fee.units).to eq(28)
          # event is prorated for 3 days of 28 days period (28 * 3 / 28 * 10 = 30)
          expect(fixed_charge_fee.amount_cents).to eq(3000)
        end
      end
    end

    context "when two subscriptions are given" do
      let(:subscription2) do
        create(
          :subscription,
          plan:,
          customer: subscription.customer,
          subscription_at: (Time.zone.now - 2.years).to_date,
          started_at: Time.zone.now - 2.years
        )
      end

      let(:invoice_subscription2) do
        create(
          :invoice_subscription,
          subscription: subscription2,
          invoice:,
          timestamp:,
          from_datetime: date_service.from_datetime,
          to_datetime: date_service.to_datetime,
          charges_from_datetime: date_service.charges_from_datetime,
          charges_to_datetime: date_service.charges_to_datetime,
          fixed_charges_from_datetime: date_service.fixed_charges_from_datetime,
          fixed_charges_to_datetime: date_service.fixed_charges_to_datetime
        )
      end

      let(:invoice_subscriptions) { [invoice_subscription, invoice_subscription2] }

      context "when plan has no minimum commitment" do
        it "creates subscription, charge and fixed charge fees for both" do
          result = invoice_service.call

          expect(result).to be_success
          expect(invoice.subscriptions.to_a).to match_array([subscription, subscription2])
          expect(invoice.payment_status).to eq("pending")
          expect(invoice.fees.subscription.count).to eq(2)
          expect(invoice.fees.charge.count).to eq(1) # 0 amount charge fee is not created for subscription 2
          expect(invoice.fees.fixed_charge.count).to eq(1)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime((timestamp - 1.day).end_of_day),
            from_datetime: match_datetime((timestamp - 1.month).beginning_of_day)
          )
        end
      end

      context "when plan has minimum commitment" do
        let(:fixed_charge) do
          create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "0.001"}, units: 10)
        end

        before do
          create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
        end

        it "creates subscription, charges and commitment fees for both" do
          result = invoice_service.call

          expect(result).to be_success
          expect(invoice.subscriptions.to_a).to match_array([subscription, subscription2])
          expect(invoice.payment_status).to eq("pending")
          expect(invoice.fees.subscription.count).to eq(2)
          expect(invoice.fees.charge.count).to eq(1) # 0 amount charge fee is not created for subscription 2
          expect(invoice.fees.commitment.count).to eq(2)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime((timestamp - 1.day).end_of_day),
            from_datetime: match_datetime((timestamp - 1.month).beginning_of_day)
          )
        end
      end
    end

    context "when subscription is terminated" do
      let(:status) { :terminated }
      let(:timestamp) { Time.zone.now.beginning_of_month - 1.day }
      let(:started_at) { Time.zone.today - 3.months }
      let(:terminated_at) { timestamp - 2.days }

      context "when plan has minimum commitment" do
        let(:fixed_charge) do
          create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "0.001"}, units: 10)
        end

        before do
          create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
        end

        it "creates a subscription and a commitment fee" do
          result = invoice_service.call

          expect(result).to be_success
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.commitment.count).to eq(1)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime(terminated_at),
            from_datetime: match_datetime(terminated_at.beginning_of_month)
          )
        end
      end

      context "when plan has no minimum commitment" do
        it "creates a subscription fee" do
          result = invoice_service.call

          expect(result).to be_success
          expect(invoice.fees.subscription.count).to eq(1)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime(terminated_at),
            from_datetime: match_datetime(terminated_at.beginning_of_month)
          )
        end
      end

      context "when charges are pay in advance and billable metric is recurring" do
        let(:billable_metric) do
          create(:billable_metric, aggregation_type: "unique_count_agg", recurring: true, field_name: "item_id")
        end

        let(:charge) do
          create(
            :standard_charge,
            :pay_in_advance,
            plan: subscription.plan,
            charge_model: "standard",
            invoiceable: true,
            billable_metric:
          )
        end

        context "when plan no minimum commitment" do
          it "does not create a charge fee or a commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.charge.count).to eq(0)
            expect(invoice.fees.commitment.count).to eq(0)
          end
        end

        context "when plan has minimum commitment" do
          let(:fixed_charge) do
            create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "0.001"}, units: 10)
          end

          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          it "does not create a charge fee but it creates a commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.charge.count).to eq(0)
            expect(invoice.fees.commitment.count).to eq(1)
          end
        end
      end

      context "when charges are pay in arrear and billable metric is recurring" do
        let(:billable_metric) do
          create(:billable_metric, aggregation_type: "unique_count_agg", recurring: true, field_name: "item_id")
        end
        let(:charge) do
          create(
            :standard_charge,
            pay_in_advance: false,
            plan: subscription.plan,
            charge_model: "standard",
            invoiceable: true,
            billable_metric:,
            prorated: false
          )
        end

        context "when plan no minimum commitment" do
          it "creates a charge fee but no minimum commitment fee", transaction: false do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.charge.count).to eq(1)
            expect(invoice.fees.commitment.count).to eq(0)
          end
        end

        context "when plan has minimum commitment" do
          let(:fixed_charge) do
            create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "0.001"}, units: 10)
          end
          let(:event) { nil }

          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          it "creates a charge fee and a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice).to have_empty_charge_fees
            expect(invoice.fees.commitment.count).to eq(1)
          end
        end
      end

      context "when termination is part of upgrade and charges are not billable" do
        let(:new_subscription) do
          create(
            :subscription,
            plan:,
            previous_subscription: subscription,
            subscription_at: started_at.to_date,
            started_at: terminated_at + 1.day,
            created_at: terminated_at + 1.day
          )
        end

        let(:billable_metric) do
          create(:billable_metric, aggregation_type: "unique_count_agg", recurring: true, field_name: "item_id")
        end

        let(:charge) do
          create(
            :standard_charge,
            :pay_in_advance,
            plan: subscription.plan,
            charge_model: "standard",
            invoiceable: true,
            billable_metric:
          )
        end

        before { new_subscription }

        context "when plan has no minimum commitment" do
          it "does not create a charge fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.charge.count).to eq(0)
          end

          it "does not create a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end

        context "when plan has minimum commitment" do
          let(:fixed_charge) do
            create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "0.001"}, units: 10)
          end

          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          it "does not create a charge fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.charge.count).to eq(0)
          end

          it "creates a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(1)
          end
        end
      end

      context "when termination is part of upgrade, charges are paid in arrears and BM is recurring" do
        let(:new_subscription) do
          create(
            :subscription,
            plan:,
            previous_subscription: subscription,
            subscription_at: started_at.to_date,
            started_at: terminated_at + 1.day,
            created_at: terminated_at + 1.day
          )
        end

        let(:billable_metric) do
          create(:billable_metric, aggregation_type: "unique_count_agg", recurring: true, field_name: "item_id")
        end

        let(:charge) do
          create(
            :standard_charge,
            pay_in_advance: false,
            plan: subscription.plan,
            charge_model: "standard",
            invoiceable: true,
            billable_metric:,
            prorated: false
          )
        end

        before { new_subscription }

        context "when plan has no minimum commitment" do
          it "does not create a charge fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.charge.count).to eq(0)
          end

          it "does not create a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end

        context "when plan has minimum commitment" do
          let(:fixed_charge) do
            create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "0.001"}, units: 10)
          end

          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          it "does not create a charge fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.charge.count).to eq(0)
          end

          it "creates a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(1)
          end
        end
      end

      context "when subscription is billed on anniversary date" do
        let(:timestamp) { Time.zone.parse("22 Mar 2022") }
        let(:started_at) { Time.zone.parse("2021-06-06 05:00:00") }
        let(:subscription_at) { started_at }
        let(:billing_time) { "anniversary" }

        context "when plan has no minimum commitment" do
          it "creates subscription fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.subscription.count).to eq(1)

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              to_datetime: match_datetime(terminated_at),
              from_datetime: match_datetime(Time.zone.parse("2022-03-06 00:00:00"))
            )
          end

          it "does not create a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end

        context "when plan has minimum commitment" do
          let(:fixed_charge) do
            create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "0.001"}, units: 10)
          end

          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          it "creates subscription fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.subscription.count).to eq(1)

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              to_datetime: match_datetime(terminated_at),
              from_datetime: match_datetime(Time.zone.parse("2022-03-06 00:00:00"))
            )
          end

          it "creates a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.commitment.count).to eq(1)
          end
        end
      end

      context "when fixed charges are pay in advance and subscription is terminated" do
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "standard",
            pay_in_advance: true,
            properties: {amount: "10"}
          )
        end

        let(:fixed_charge_event) do
          create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: event_timestamp, units: 5, created_at: event_timestamp)
        end

        context "when plan has no minimum commitment" do
          it "does not create a fixed charge fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.fixed_charge.count).to eq(0)
          end
        end
      end

      context "when fixed charges are pay in arrear and subscription is terminated" do
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "standard",
            pay_in_advance: false,
            properties: {amount: "10"}
          )
        end

        let(:fixed_charge_event) do
          create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: event_timestamp, units: 5, created_at: event_timestamp)
        end

        context "when plan has no minimum commitment" do
          it "creates a fixed charge fee but no minimum commitment fee", transaction: false do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.fixed_charge.count).to eq(1)
            expect(invoice.fees.commitment.count).to eq(0)
          end
        end
      end

      context "when termination is part of upgrade" do
        let(:new_subscription) do
          create(
            :subscription,
            plan:,
            previous_subscription: subscription,
            subscription_at: started_at.to_date,
            started_at: terminated_at + 1.day,
            created_at: terminated_at + 1.day
          )
        end

        let(:fixed_charge_event) do
          create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: event_timestamp, units: 5, created_at: event_timestamp)
        end

        before do
          new_subscription
        end

        context "when fixed charge is pay in advance" do
          let(:fixed_charge) do
            create(
              :fixed_charge,
              plan: subscription.plan,
              charge_model: "standard",
              pay_in_advance: true,
              properties: {amount: "10"}
            )
          end

          it "does not create a fixed charge fee for the old subscription" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.fixed_charge.count).to eq(0)
          end
        end

        context "when fixed charge is pay in arrear" do
          let(:fixed_charge) do
            create(
              :fixed_charge,
              plan: subscription.plan,
              charge_model: "standard",
              pay_in_advance: false,
              properties: {amount: "10"}
            )
          end

          it "does create a fixed charge fee for the old subscription pay in arrears fixed charge" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.fixed_charge.count).to eq(1)
          end
        end
      end
    end

    context "when plan is pay in advance" do
      let(:pay_in_advance) { true }

      context "when billed on anniversary date" do
        let(:timestamp) { Time.zone.parse("07 Mar 2022") }
        let(:started_at) { Time.zone.parse("06 Jun 2021").to_date }
        let(:subscription_at) { started_at }
        let(:billing_time) { :anniversary }

        let(:event) { nil }

        context "when plan has no minimum commitment" do
          it "creates a subscription fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.subscriptions.first).to eq(subscription)
            expect(invoice.payment_status).to eq("pending")
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice).to have_empty_charge_fees

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              to_datetime: match_datetime(Time.zone.parse("2022-04-05 23:59:59")),
              from_datetime: match_datetime(Time.zone.parse("2022-03-06 00:00:00"))
            )
          end

          it "does not create a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end

        context "when plan has minimum commitment" do
          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          it "creates a subscription fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.subscriptions.first).to eq(subscription)
            expect(invoice.payment_status).to eq("pending")
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice).to have_empty_charge_fees

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              to_datetime: match_datetime(Time.zone.parse("2022-04-05 23:59:59")),
              from_datetime: match_datetime(Time.zone.parse("2022-03-06 00:00:00"))
            )
          end

          it "does not create a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end
      end

      context "when plan is in trial period" do
        let(:trial_period) { 45 }
        let(:started_at) { 40.days.ago }

        it "does not create a subscription fee" do
          subscription.created_at
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.fees.subscription.count).to eq(0)
        end

        it "creates a fixed charge fee even during trial period" do
          result = invoice_service.call

          expect(result).to be_success
          expect(invoice.fees.fixed_charge.count).to eq(1)
        end
      end

      context "when fixed charges are pay in advance" do
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "standard",
            pay_in_advance: true,
            properties: {amount: "10"}
          )
        end

        let(:fixed_charge_event) do
          create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: event_timestamp, units: 5, created_at: event_timestamp)
        end

        it "creates subscription and fixed charge fees with correct boundaries" do
          result = invoice_service.call

          expect(result).to be_success
          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.payment_status).to eq("pending")
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.fixed_charge.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription[:to_datetime].to_date).to eq(Time.zone.today.end_of_month)
          expect(invoice_subscription[:from_datetime].to_date).to eq(Time.zone.today.beginning_of_month)

          fixed_charge_fee_properties = invoice.fees.fixed_charge.first.properties
          expect(fixed_charge_fee_properties["fixed_charges_from_datetime"].to_date).to match_datetime(Time.zone.today.beginning_of_month)
          expect(fixed_charge_fee_properties["fixed_charges_to_datetime"].to_date).to match_datetime(Time.zone.today.end_of_month)

          charge_fee_properties = invoice.fees.charge.first.properties
          expect(charge_fee_properties["charges_from_datetime"].to_date).to match_datetime((Time.zone.today - 1.month).beginning_of_month)
          expect(charge_fee_properties["charges_to_datetime"].to_date).to match_datetime((Time.zone.today - 1.month).end_of_month)
        end
      end

      context "when subscription was already billed earlier the same day" do
        let(:timestamp) { Time.current }
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "standard",
            pay_in_advance: true,
            properties: {amount: "10"}
          )
        end

        before do
          create(:fee, subscription:)
          create(:fixed_charge_fee, subscription:, fixed_charge:, created_at: timestamp)
        end

        context "when plan has no minimum commitment" do
          it "does not create any subscription fees" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.subscription.count).to eq(0)
            expect(invoice.invoice_subscriptions.count).to eq(1)
            expect(invoice.invoice_subscriptions.first.recurring).to be_falsey
          end

          it "does not create a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success
            expect(invoice.fees.commitment.count).to eq(0)
          end

          # TODO: this will be solved with the service that calculates delta for fixed charges
          # it "does not create a fixed charge fee" do
          #   result = invoice_service.call

          #   expect(result).to be_success
          #   expect(invoice.fees.fixed_charge.count).to eq(0)
          # end
        end

        context "when plan has minimum commitment" do
          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          it "does not create any subscription fees" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.subscription.count).to eq(0)
            expect(invoice.invoice_subscriptions.count).to eq(1)
            expect(invoice.invoice_subscriptions.first.recurring).to be_falsey
          end

          it "does not create a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end
      end

      context "when subscription started in the past" do
        let(:created_at) { timestamp }

        it "creates subscription, charge and fixed charge fees" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)
          expect(invoice.fees.fixed_charge.count).to eq(1)
        end
      end

      context "when subscription started on creation day" do
        let(:event) { nil }

        it "does not create any charge fees" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice).to have_empty_charge_fees
        end
      end

      context "when subscription is an upgrade" do
        let(:timestamp) { Time.zone.parse("30 Sep 2022 00:31:00") }
        let(:started_at) { Time.zone.parse("12 Aug 2022 00:31:00") }
        let(:terminated_at) { timestamp - 2.days }
        let(:previous_plan) { create(:plan, amount_cents: 10_000, interval: :yearly, pay_in_advance: true) }

        let(:previous_subscription) do
          create(
            :subscription,
            plan: previous_plan,
            subscription_at: started_at.to_date,
            started_at:,
            status: :terminated,
            terminated_at:
          )
        end

        let(:subscription) do
          create(
            :subscription,
            plan:,
            previous_subscription:,
            subscription_at: started_at.to_date,
            started_at: terminated_at + 1.day,
            created_at: terminated_at + 1.day
          )
        end

        context "when plan has no minimum commitment" do
          it "creates pro-rated subscription fee and no charge fees" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice).to be_payment_pending
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice).to have_empty_charge_fees

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              to_datetime: match_datetime(subscription.started_at.end_of_month),
              from_datetime: match_datetime(subscription.started_at.beginning_of_day)
            )
          end

          it "does not create a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end

        context "when plan has minimum commitment" do
          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          it "creates pro-rated subscription fee and no charge fees" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice).to be_payment_pending
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice).to have_empty_charge_fees
            expect(invoice.fees.fixed_charge.count).to eq(1)

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              to_datetime: match_datetime(subscription.started_at.end_of_month),
              from_datetime: match_datetime(subscription.started_at.beginning_of_day)
            )
          end

          it "does not creates a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end
      end

      context "when subscription is terminated after an upgrade" do
        let(:next_subscription) do
          create(
            :subscription,
            plan: next_plan,
            subscription_at: started_at.to_date,
            started_at: terminated_at,
            status: :active,
            billing_time: :calendar,
            previous_subscription: subscription,
            customer: subscription.customer
          )
        end

        let(:started_at) { Time.zone.parse("07 Mar 2022") }
        let(:terminated_at) { Time.zone.parse("17 Oct 2022 12:35:12") }
        let(:timestamp) { Time.zone.parse("17 Oct 2022 15:00") }

        let(:subscription) do
          create(
            :subscription,
            plan:,
            subscription_at: started_at.to_date,
            started_at:,
            status: :terminated,
            terminated_at:,
            billing_time: :calendar
          )
        end

        let(:next_plan) { create(:plan, interval: :monthly, amount_cents: 2000) }

        before { next_subscription }

        context "when plan has no minimum commitment" do
          it "creates only the charge fees" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.subscription.count).to eq(0)
            expect(invoice).to have_empty_charge_fees
            expect(invoice.fees.fixed_charge.count).to eq(1) # fixed charge is pay in arrears - sub termination generated fee

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              charges_from_datetime: match_datetime(Time.zone.parse("2022-10-01 00:00:00")),
              charges_to_datetime: match_datetime(terminated_at)
            )
          end

          it "does not creates a minimum commitment fee" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.fees.commitment.count).to eq(0)
          end
        end

        context "when plan has minimum commitment" do
          before do
            create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000)
          end

          context "when plan has no minimum commitment" do
            it "creates only the charge fees" do
              result = invoice_service.call

              expect(result).to be_success

              expect(invoice.fees.subscription.count).to eq(0)
              expect(invoice).to have_empty_charge_fees
              # Fixed charge is pay in arrears - sub termination generated fee
              expect(invoice.fees.fixed_charge.count).to eq(1)

              invoice_subscription = invoice.invoice_subscriptions.first
              expect(invoice_subscription).to have_attributes(
                charges_from_datetime: match_datetime(Time.zone.parse("2022-10-01 00:00:00")),
                charges_to_datetime: match_datetime(terminated_at)
              )
            end

            it "does not creates a minimum commitment fee" do
              result = invoice_service.call

              expect(result).to be_success

              expect(invoice.fees.commitment.count).to eq(0)
            end
          end
        end
      end
    end

    context "when billed yearly" do
      let(:timestamp) { Time.zone.now.beginning_of_year }
      let(:interval) { "yearly" }

      it "updates the invoice accordingly" do
        result = invoice_service.call

        expect(result).to be_success

        expect(invoice.subscriptions.first).to eq(subscription)
        expect(invoice.fees.subscription.count).to eq(1)
        expect(invoice.fees.charge.count).to eq(1)

        invoice_subscription = invoice.invoice_subscriptions.first
        expect(invoice_subscription).to have_attributes(
          to_datetime: match_datetime((timestamp - 1.day).end_of_day),
          from_datetime: match_datetime((timestamp - 1.year).beginning_of_day)
        )
      end

      context "when subscription is billed on anniversary date" do
        let(:timestamp) { Time.zone.parse("07 Jun 2022") }
        let(:started_at) { Time.zone.parse("06 Jun 2020").to_date }
        let(:subscription_at) { started_at }
        let(:billing_time) { :anniversary }

        let(:event) { nil }

        it "updates the invoice accordingly" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.fixed_charge.count).to eq(1)
          expect(invoice).to have_empty_charge_fees # Because we didn't fake usage events

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime(Time.zone.parse("2022-06-05 23:59:59")),
            from_datetime: match_datetime(Time.zone.parse("2021-06-06 00:00:00"))
          )
        end

        context "when started_at in the past" do
          let(:timestamp) { Time.zone.parse(started_at.to_s).end_of_year + 1.day }
          let(:started_at) { created_at - 2.months }
          let(:created_at) { Time.zone.parse("2025-01-21T00:10:00") }
          let(:event_timestamp) { created_at }
          let(:fixed_charge_event) { create(:fixed_charge_event, fixed_charge:, units: 10, timestamp: started_at, created_at: created_at) }

          it "updates the invoice accordingly" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.subscriptions.first).to eq(subscription)
            expect(invoice.fees.subscription.count).to eq(0)
            expect(invoice).to have_empty_charge_fees # Because we didn't fake usage events

            # plan is billed anniversary on 21 of November (started_at, 2024). At the timestamp, 1st Jan 2025,
            # previous billing period is "empty" - 21Nov 2024 - 21 Nov 2024, because it's not current usage, so we get an "empty"
            # boundaries and cannot fetch any usage
            expect(invoice.fees.fixed_charge.count).to eq(0)
          end
        end

        context "when plan is pay in advance" do
          let(:pay_in_advance) { true }

          it "updates the invoice accordingly" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.subscriptions.first).to eq(subscription)
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice).to have_empty_charge_fees # Because we didn't fake usage events

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              to_datetime: match_datetime(Time.zone.parse("2023-06-05 23:59:59")),
              from_datetime: match_datetime(Time.zone.parse("2022-06-06 00:00:00"))
            )
          end
        end

        context "when plan is pay in advance and started_at in the past" do
          let(:pay_in_advance) { true }
          let(:timestamp) { Time.current.end_of_month + 1.day }
          let(:started_at) { Time.current - 2.months }
          let(:created_at) { Time.current }

          it "updates the invoice accordingly" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.subscriptions.first).to eq(subscription)
            expect(invoice.fees.subscription.count).to eq(0)
            expect(invoice).to have_empty_charge_fees # Because we didn't fake usage events
          end
        end

        context "when plan is pay in advance and started_at in the past and billed on second year" do
          let(:pay_in_advance) { true }
          let(:timestamp) { started_at + 1.year }
          let(:started_at) { Time.current - 2.months }
          let(:created_at) { Time.current }

          it "updates the invoice accordingly" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.subscriptions.first).to eq(subscription)
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice).to have_empty_charge_fees # Because we didn't fake usage events
          end
        end
      end

      context "when billed yearly on first year" do
        let(:timestamp) { Time.zone.parse(started_at.to_s).end_of_year + 1.day }
        let(:started_at) { Time.zone.today - 3.months }

        it "updates the invoice accordingly" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime((timestamp - 1.day).end_of_day),
            from_datetime: match_datetime(subscription.subscription_at.beginning_of_day)
          )
        end
      end
    end

    context "when billed quarterly" do
      let(:timestamp) { Time.zone.now.beginning_of_year }
      let(:started_at) { Time.zone.now.beginning_of_year - 2.years }
      let(:interval) { "quarterly" }

      it "updates the invoice accordingly" do
        result = invoice_service.call

        expect(result).to be_success

        expect(invoice.subscriptions.first).to eq(subscription)
        expect(invoice.fees.subscription.count).to eq(1)
        expect(invoice.fees.charge.count).to eq(1)

        invoice_subscription = invoice.invoice_subscriptions.first
        expect(invoice_subscription).to have_attributes(
          to_datetime: match_datetime((timestamp - 1.day).end_of_day),
          from_datetime: match_datetime((timestamp - 2.days).beginning_of_quarter.beginning_of_day),
          charges_to_datetime: match_datetime((timestamp - 1.day).end_of_day),
          charges_from_datetime: match_datetime((timestamp - 2.days).beginning_of_quarter.beginning_of_day)
        )
      end

      context "when subscription is billed on anniversary date" do
        let(:timestamp) { Time.zone.parse("07 Jun 2022") }
        let(:started_at) { Time.zone.parse("06 Jun 2020").to_date }
        let(:subscription_at) { started_at }
        let(:billing_time) { :anniversary }

        it "updates the invoice accordingly" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime(Time.zone.parse("2022-06-05 23:59:59")),
            from_datetime: match_datetime(Time.zone.parse("2022-03-06 00:00:00")),
            charges_to_datetime: match_datetime(Time.zone.parse("2022-06-05 23:59:59")),
            charges_from_datetime: match_datetime(Time.zone.parse("2022-03-06 00:00:00"))
          )
        end

        context "when plan is pay in advance" do
          let(:pay_in_advance) { true }
          let(:old_invoice_subscription) { create(:invoice_subscription, invoice: old_invoice, subscription:) }
          let(:old_invoice) do
            create(
              :invoice,
              created_at: started_at - 3.months,
              customer: subscription.customer,
              organization: plan.organization
            )
          end

          before { old_invoice_subscription }

          it "updates the invoice accordingly" do
            result = invoice_service.call

            expect(result).to be_success

            expect(invoice.subscriptions.first).to eq(subscription)
            expect(invoice.fees.subscription.count).to eq(1)
            expect(invoice.fees.charge.count).to eq(1)

            invoice_subscription = invoice.invoice_subscriptions.first
            expect(invoice_subscription).to have_attributes(
              to_datetime: match_datetime(Time.zone.parse("2022-09-05 23:59:59")),
              from_datetime: match_datetime(Time.zone.parse("2022-06-06 00:00:00")),
              charges_to_datetime: match_datetime(Time.zone.parse("2022-06-05 23:59:59")),
              charges_from_datetime: match_datetime(Time.zone.parse("2022-03-06 00:00:00"))
            )
          end
        end
      end

      context "when billed quarterly on first billing day" do
        let(:timestamp) { Time.zone.parse("01 Jan 2022") }
        let(:started_at) { Time.zone.parse("12 Nov 2021").to_date }
        let(:subscription_at) { started_at }

        it "updates the invoice accordingly" do
          result = invoice_service.call

          expect(result).to be_success

          expect(invoice.subscriptions.first).to eq(subscription)
          expect(invoice.fees.subscription.count).to eq(1)
          expect(invoice.fees.charge.count).to eq(1)

          invoice_subscription = invoice.invoice_subscriptions.first
          expect(invoice_subscription).to have_attributes(
            to_datetime: match_datetime((timestamp - 1.day).end_of_day),
            from_datetime: match_datetime(subscription.subscription_at.beginning_of_day),
            charges_to_datetime: match_datetime((timestamp - 1.day).end_of_day),
            charges_from_datetime: match_datetime(subscription.subscription_at.beginning_of_day)
          )
        end
      end
    end

    context "with credit" do
      let(:credit_note) do
        create(
          :credit_note,
          customer: subscription.customer,
          total_amount_cents: 10,
          total_amount_currency: plan.amount_currency,
          balance_amount_cents: 10,
          balance_amount_currency: plan.amount_currency,
          credit_amount_cents: 10,
          credit_amount_currency: plan.amount_currency
        )
      end

      before { credit_note }

      it "updates the invoice accordingly" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.fees_amount_cents).to eq(10200)
        expect(result.invoice.taxes_amount_cents).to eq(2040)
        expect(result.invoice.total_amount_cents).to eq(12230)
        expect(result.invoice.credits.count).to eq(1)

        credit = result.invoice.credits.first
        expect(credit.credit_note).to eq(credit_note)
        expect(credit.amount_cents).to eq(10)
      end
    end

    context "with applied prepaid credits" do
      let(:timestamp) { Time.zone.now.beginning_of_month }
      let(:wallet) { create(:wallet, :with_inbound_transaction, customer: subscription.customer, balance: "0.30", credits_balance: "0.30") }

      let(:plan) do
        create(:plan, interval: "monthly")
      end

      before { wallet }

      it "updates the invoice accordingly" do
        result = invoice_service.call

        expect(result).to be_success

        expect(result.invoice.fees.first.properties["to_datetime"])
          .to eq (timestamp - 1.day).end_of_day.as_json
        expect(result.invoice.fees.first.properties["from_datetime"])
          .to eq (timestamp - 1.month).beginning_of_day.as_json
        expect(result.invoice.subscriptions.first).to eq(subscription)
        expect(result.invoice.fees.subscription.count).to eq(1)
        expect(result.invoice.fees.charge.count).to eq(1)
        expect(result.invoice.fees.fixed_charge.count).to eq(1)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(10200)
        expect(result.invoice.taxes_amount_cents).to eq(2040)
        expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(12240)
        expect(result.invoice.prepaid_credit_amount_cents).to eq(30)
        expect(result.invoice.total_amount_cents).to eq(12210)
        expect(result.invoice.wallet_transactions.count).to eq(1)
      end

      it "updates wallet balance" do
        invoice_service.call

        expect(wallet.reload.balance).to eq(0.0)
      end

      context "when invoice amount in cents is zero" do
        let(:applied_coupon) do
          create(
            :applied_coupon,
            customer: subscription.customer,
            amount_cents: 120,
            amount_currency: plan.amount_currency
          )
        end

        let(:event) { nil }
        let(:fixed_charge_event) { nil }

        before { applied_coupon }

        it "does not create any wallet transactions" do
          result = invoice_service.call

          expect(result.invoice.wallet_transactions.exists?).to be(false)
        end
      end
    end

    context "with all types of credits" do
      let(:plan) { create(:plan, organization:, interval:, pay_in_advance:, trial_period:, amount_cents: 10_000) }
      let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 10) }
      let(:billable_metric1) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
      let(:billable_metric2) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
      let(:billable_metric3) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
      let(:billable_metric4) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
      let(:coupon1) { create(:coupon, organization:, coupon_type: "percentage", limited_billable_metrics: true, percentage_rate: 50.00) }
      let(:coupon2) { create(:coupon, organization:) }
      let(:coupon_target) { create(:coupon_billable_metric, coupon: coupon1, billable_metric: billable_metric1) }
      let(:wallet) do
        create(:wallet, :with_inbound_transaction, organization:, customer: subscription.customer, balance: "50_000", credits_balance: "50_000", allowed_fee_types: %w[charge])
      end
      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon: coupon1,
          customer: subscription.customer,
          percentage_rate: 50.00
        )
      end
      let(:applied_coupon2) do
        create(
          :applied_coupon,
          coupon: coupon2,
          customer: subscription.customer,
          amount_cents: 1_000
        )
      end

      let(:charge1) do
        create(
          :standard_charge,
          plan: subscription.plan,
          organization:,
          charge_model: "standard",
          billable_metric: billable_metric1,
          properties: {amount: "10"}
        )
      end
      let(:event1) do
        create(
          :event,
          organization: organization,
          subscription: subscription,
          code: billable_metric1.code,
          timestamp: event_timestamp
        )
      end
      let(:charge2) do
        create(
          :standard_charge,
          plan: subscription.plan,
          organization:,
          charge_model: "standard",
          billable_metric: billable_metric2,
          properties: {amount: "20"}
        )
      end
      let(:event2) do
        create(
          :event,
          organization: organization,
          subscription: subscription,
          code: billable_metric2.code,
          timestamp: event_timestamp
        )
      end
      let(:charge3) do
        create(
          :standard_charge,
          plan: subscription.plan,
          organization:,
          charge_model: "standard",
          billable_metric: billable_metric3,
          properties: {amount: "30"}
        )
      end
      let(:event3) do
        create(
          :event,
          organization: organization,
          subscription: subscription,
          code: billable_metric3.code,
          timestamp: event_timestamp
        )
      end
      let(:charge4) do
        create(
          :standard_charge,
          plan: subscription.plan,
          organization:,
          charge_model: "standard",
          billable_metric: billable_metric4,
          properties: {amount: "40"}
        )
      end
      let(:event4) do
        create(
          :event,
          organization: organization,
          subscription: subscription,
          code: billable_metric4.code,
          timestamp: event_timestamp
        )
      end
      let(:progressive_invoice) do
        create(
          :invoice,
          :with_subscriptions,
          customer:,
          status: "finalized",
          invoice_type: :progressive_billing,
          subscriptions: [subscription],
          fees_amount_cents: 3_000,
          issuing_date: timestamp - 5.days,
          created_at: timestamp - 5.days
        )
      end
      let(:progressive_fee) do
        create(:charge_fee, amount_cents: 3_000, charge: charge3, invoice: progressive_invoice)
      end
      let(:credit_note) do
        create(
          :credit_note,
          customer: subscription.customer,
          total_amount_cents: 1_000,
          total_amount_currency: plan.amount_currency,
          balance_amount_cents: 1_000,
          balance_amount_currency: plan.amount_currency,
          credit_amount_cents: 1_000,
          credit_amount_currency: plan.amount_currency
        )
      end

      let(:event) { nil }

      before do
        charge1
        charge2
        charge3
        charge4
        event1
        event2
        event3
        event4
        progressive_invoice
        progressive_fee
        progressive_invoice.invoice_subscriptions.first.update!(
          charges_from_datetime: progressive_invoice.issuing_date - 1.month,
          charges_to_datetime: progressive_invoice.issuing_date,
          timestamp: progressive_invoice.issuing_date
        )
        applied_coupon
        applied_coupon2
        coupon_target
        credit_note
        wallet
      end

      it "updates the invoice accordingly" do
        result = invoice_service.call

        expect(result).to be_success
        # 100_00  - fixed_charges
        # 100_00  - charges
        # 100_00 - subscription
        expect(result.invoice.fees_amount_cents).to eq(300_00)
        # Billing entity tax is 10%
        # subtotal = fees_amount_cents - coupons_amount_cents - progressive_billing_credit_amount_cents
        expect(result.invoice.progressive_billing_credit_amount_cents).to eq(30_00)
        expect(result.invoice.coupons_amount_cents).to eq(15_00)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(255_00)
        expect(result.invoice.taxes_amount_cents).to eq(25_50)
        expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(280_50)

        expect(result.invoice.total_amount_cents).to eq(204_15) # 280_50 - 10_00 (credit note) - 66_35 (wallet)
      end
    end

    # TODO: this should not be the case when we merge everything, as we're going to bill this case differently
    context "when subscription that is started" do
      let(:subscription) { create(:subscription, plan:, started_at:, customer:) }
      let(:date_service) do
        Subscriptions::DatesService.new_instance(
          subscription,
          Time.zone.at(timestamp),
          current_usage: false
        )
      end

      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          subscription:,
          invoice:,
          invoicing_reason: :subscription_starting,
          timestamp:,
          from_datetime: date_service.from_datetime,
          to_datetime: date_service.to_datetime,
          charges_from_datetime: date_service.charges_from_datetime,
          charges_to_datetime: date_service.charges_to_datetime,
          fixed_charges_from_datetime: date_service.fixed_charges_from_datetime,
          fixed_charges_to_datetime: date_service.fixed_charges_to_datetime
        )
      end
      let(:plan) { create(:plan, pay_in_advance:) }
      let(:charge) { create(:standard_charge, plan:, pay_in_advance: charge_pay_in_advance) }
      let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance: fixed_charge_pay_in_advance) }
      let(:pay_in_advance) { false }
      let(:charge_pay_in_advance) { false }
      let(:fixed_charge_pay_in_advance) { false }
      let(:started_at) { DateTime.parse("01 Jan 2022") }
      let(:timestamp) { started_at }
      let(:invoice) { create(:invoice) }
      let(:fixed_charge_event) { create(:fixed_charge_event, fixed_charge:, units: 10, timestamp: started_at, created_at: started_at) }

      before do
        invoice
        charge
        fixed_charge_event
        invoice_subscription
      end

      it "creates a subscription fee with amount 0, does not create charge nor fixed charge fees" do
        result = invoice_service.call

        expect(result.invoice.fees.subscription.count).to eq(1)
        expect(result.invoice.fees.charge.count).to eq(0)
        expect(result.invoice.fees.fixed_charge.count).to eq(0)
      end

      context "when fixed_charge is pay in advance" do
        let(:fixed_charge_pay_in_advance) { true }

        it "does not create a subscription fee, does not create charge fee, creates fixed charge fee" do
          result = invoice_service.call

          expect(result.invoice.fees.subscription.count).to eq(0)
          expect(result.invoice.fees.charge.count).to eq(0)
          # To Be changed when we actually generate fixed charge fees
          expect(result.invoice.fees.fixed_charge.count).to eq(0)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        it "creates a subscription fee, does not create charge fee, does not create fixed charge fee" do
          result = invoice_service.call

          expect(result.invoice.fees.subscription.count).to eq(1)
          expect(result.invoice.fees.charge.count).to eq(0)
          expect(result.invoice.fees.fixed_charge.count).to eq(0)
        end

        context "when fixed_charge is pay in advance" do
          let(:fixed_charge_pay_in_advance) { true }

          it "creates a subscription fee, does not create charge fee, creates fixed charge fee" do
            result = invoice_service.call

            expect(result.invoice.fees.subscription.count).to eq(1)
            expect(result.invoice.fees.charge.count).to eq(0)
            # To Be changed when we actually generate fixed charge fees
            expect(result.invoice.fees.fixed_charge.count).to eq(0)
          end
        end
      end
    end

    # this case might happen because we only started populating fixed_charge boundaries in the last PR,
    # and we can have some invoices that we're recalculating with old invoice_subscriptions
    context "when invoice has an invoice_subscription with empty fixed_charge boundaries" do
      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          subscription:,
          invoice:,
          timestamp:,
          from_datetime: date_service.from_datetime,
          to_datetime: date_service.to_datetime,
          charges_from_datetime: date_service.charges_from_datetime,
          charges_to_datetime: date_service.charges_to_datetime,
          fixed_charges_from_datetime: nil,
          fixed_charges_to_datetime: nil
        )
      end

      it "does not fail and does not create fixed charge fees" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.fees.fixed_charge.count).to eq(0)
      end
    end
  end

  context "when subscription is incomplete" do
    let(:status) { :incomplete }
    let(:timestamp) { Time.zone.parse("07 Mar 2022") }
    let(:started_at) { Time.zone.parse("07 Mar 2022") }
    let(:billing_time) { :anniversary }
    let(:pay_in_advance) { true }
    let(:fixed_charge) do
      create(:fixed_charge, plan: subscription.plan, charge_model: "standard", properties: {amount: "10"}, units: 10, pay_in_advance: true)
    end

    it "creates subscription and fixed charge fees" do
      result = invoice_service.call

      expect(result).to be_success
      expect(invoice.fees.subscription.count).to eq(1)
      expect(invoice.fees.fixed_charge.count).to eq(1)
    end
  end

  describe "#should_create_yearly_subscription_fee?" do
    subject(:method_call) { invoice_service.send(:should_create_yearly_subscription_fee?, subscription) }

    let(:timestamp) { DateTime.parse("01 Apr 2022") }
    let(:started_at) { DateTime.parse("31 Mar 2021") }
    let(:created_at) { started_at }
    let(:terminated_at) { nil }

    context "when plan is not yearly" do
      let(:interval) { "monthly" }

      it "returns true" do
        expect(subject).to eq(true)
      end
    end

    context "when plan is yearly" do
      let(:interval) { "yearly" }

      context "when plan is pay in arrears" do
        let(:pay_in_advance) { false }

        context "when billing_time is anniversary" do
          let(:billing_time) { :anniversary }

          context "when subscription is terminated" do
            it "returns true" do
              subscription.status = :terminated
              subscription.terminated_at = Time.zone.now
              expect(subject).to eq(true)
            end
          end

          context "when subscription is not terminated" do
            context "when it's the first month" do
              it "returns true" do
                expect(subject).to eq(true)
              end
            end

            context "when it's not the first month" do
              let(:timestamp) { DateTime.parse("01 May 2022") }

              it "returns false when it's not the first month" do
                expect(subject).to eq(false)
              end
            end
          end
        end

        context "when billing_time is calendar" do
          let(:billing_time) { :calendar }

          context "when subscription is terminated" do
            it "returns true" do
              subscription.status = :terminated
              subscription.terminated_at = Time.zone.now
              expect(subject).to eq(true)
            end
          end

          context "when subscription is not terminated" do
            context "when it's the first month" do
              let(:timestamp) { DateTime.parse("01 Jan 2023") }

              it "returns true" do
                expect(subject).to eq(true)
              end
            end

            context "when it's not the first month" do
              it "returns false when it's not the first month" do
                expect(subject).to eq(false)
              end
            end
          end
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        context "when billing_time is calendar" do
          let(:billing_time) { :calendar }

          context "when subscription started in the past" do
            let(:created_at) { started_at + 1.month }

            context "when it's the first month in yearly period" do
              context "when it is not the first month in first yearly period" do
                let(:started_at) { DateTime.parse("01 Jan 2022") }
                let(:timestamp) { DateTime.parse("01 Jan 2022") + 3.years }

                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it is the first month in first yearly period" do
                let(:timestamp) { DateTime.parse("01 Jan 2022") }
                let(:started_at) { DateTime.parse("01 Jan 2022") }

                it "returns false" do
                  expect(subject).to eq(false)
                end
              end
            end

            context "when it's not the first month in yearly period" do
              let(:started_at) { DateTime.parse("01 Jan 2022") }
              let(:timestamp) { DateTime.parse("01 Feb 2022") + 3.years }

              it "returns false" do
                expect(subject).to eq(false)
              end
            end
          end

          context "when subscription did not start in the past" do
            context "when it's the first month in yearly period" do
              let(:started_at) { DateTime.parse("01 Jan 2022") }
              let(:timestamp) { DateTime.parse("01 Jan 2022") + 3.years }

              context "when it has not been billed yet" do
                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it has been billed" do
                before do
                  allow(subscription).to receive(:already_billed?).and_return(true)
                end

                it "returns true" do
                  expect(subject).to eq(true)
                end
              end
            end

            context "when it's not the first month in yearly period" do
              let(:started_at) { DateTime.parse("01 Jan 2022") }
              let(:timestamp) { DateTime.parse("01 Feb 2022") + 3.years }

              context "when it has not been billed yet" do
                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it has been billed" do
                before do
                  allow(subscription).to receive(:already_billed?).and_return(true)
                end

                it "returns false" do
                  expect(subject).to eq(false)
                end
              end
            end
          end
        end

        context "when billing_time is anniversary" do
          let(:billing_time) { :anniversary }

          context "when subscription started in the past" do
            let(:created_at) { started_at + 1.month }

            context "when it's the first month in yearly period" do
              context "when it is not the first month in first yearly period" do
                let(:started_at) { DateTime.parse("01 Jun 2022") }
                let(:timestamp) { DateTime.parse("01 Jun 2022") + 3.years }

                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it is the first month in first yearly period" do
                let(:timestamp) { DateTime.parse("01 Jun 2022") }
                let(:started_at) { DateTime.parse("01 Jun 2022") }

                it "returns false" do
                  expect(subject).to eq(false)
                end
              end
            end

            context "when it's not the first month in yearly period" do
              let(:started_at) { DateTime.parse("01 Jun 2022") }
              let(:timestamp) { DateTime.parse("01 Jul 2022") + 3.years }

              it "returns false" do
                expect(subject).to eq(false)
              end
            end
          end

          context "when subscription did not start in the past" do
            context "when it's the first month in yearly period" do
              let(:started_at) { DateTime.parse("01 Jun 2022") }
              let(:timestamp) { DateTime.parse("01 Jun 2022") + 3.years }

              context "when it has not been billed yet" do
                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it has been billed" do
                before do
                  allow(subscription).to receive(:already_billed?).and_return(true)
                end

                it "returns true" do
                  expect(subject).to eq(true)
                end
              end
            end

            context "when it's not the first month in yearly period" do
              let(:started_at) { DateTime.parse("01 Jun 2022") }
              let(:timestamp) { DateTime.parse("01 Jul 2022") + 3.years }

              context "when it has not been billed yet" do
                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it has been billed" do
                before do
                  allow(subscription).to receive(:already_billed?).and_return(true)
                end

                it "returns false" do
                  expect(subject).to eq(false)
                end
              end
            end
          end
        end
      end
    end
  end

  describe "#should_create_semiannual_subscription_fee?" do
    subject(:method_call) { invoice_service.send(:should_create_semiannual_subscription_fee?, subscription) }

    let(:timestamp) { DateTime.parse("01 Apr 2022") }
    let(:started_at) { DateTime.parse("31 Mar 2021") }
    let(:created_at) { started_at }
    let(:terminated_at) { nil }

    context "when plan is not semiannual" do
      let(:interval) { "monthly" }

      it "returns true" do
        expect(subject).to eq(true)
      end
    end

    context "when plan is semiannual" do
      let(:interval) { "semiannual" }

      context "when plan is pay in arrears" do
        let(:pay_in_advance) { false }

        context "when billing_time is anniversary" do
          let(:billing_time) { :anniversary }

          context "when subscription is terminated" do
            it "returns true" do
              subscription.status = :terminated
              subscription.terminated_at = Time.zone.now
              expect(subject).to eq(true)
            end
          end

          context "when subscription is not terminated" do
            context "when it's the first month" do
              it "returns true" do
                expect(subject).to eq(true)
              end
            end

            context "when it's the seventh month" do
              let(:timestamp) { DateTime.parse("01 Oct 2022") }

              it "returns true" do
                expect(subject).to eq(true)
              end
            end

            context "when it's not the first month" do
              let(:timestamp) { DateTime.parse("01 May 2022") }

              it "returns false when it's not the first month" do
                expect(subject).to eq(false)
              end
            end
          end
        end

        context "when billing_time is calendar" do
          let(:billing_time) { :calendar }

          context "when subscription is terminated" do
            it "returns true" do
              subscription.status = :terminated
              subscription.terminated_at = Time.zone.now
              expect(subject).to eq(true)
            end
          end

          context "when subscription is not terminated" do
            context "when it's the first month" do
              let(:timestamp) { DateTime.parse("01 Jan 2023") }

              it "returns true" do
                expect(subject).to eq(true)
              end
            end

            context "when it's the seventh month" do
              let(:timestamp) { DateTime.parse("01 Jul 2023") }

              it "returns true" do
                expect(subject).to eq(true)
              end
            end

            context "when it's not the first or seventh month" do
              let(:timestamp) { DateTime.parse("01 Aug 2023") }

              it "returns false when it's not the first month" do
                expect(subject).to eq(false)
              end
            end
          end
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        context "when billing_time is calendar" do
          let(:billing_time) { :calendar }

          context "when subscription started in the past" do
            let(:created_at) { started_at + 1.month }

            context "when it's the first month in semiannual period" do
              context "when it is not the first month in first semiannual period" do
                let(:started_at) { DateTime.parse("01 Jan 2022") }
                let(:timestamp) { DateTime.parse("01 Jan 2022") + 3.years }

                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it is the first month in first semiannual period" do
                let(:timestamp) { DateTime.parse("01 Jan 2022") }
                let(:started_at) { DateTime.parse("01 Jan 2022") }

                it "returns false" do
                  expect(subject).to eq(false)
                end
              end
            end

            context "when it's not the first month in semiannual period" do
              let(:started_at) { DateTime.parse("01 Jan 2022") }
              let(:timestamp) { DateTime.parse("01 Feb 2022") + 3.years }

              it "returns false" do
                expect(subject).to eq(false)
              end
            end
          end

          context "when subscription did not start in the past" do
            context "when it's the first month in semiannual period" do
              let(:started_at) { DateTime.parse("01 Jan 2022") }
              let(:timestamp) { DateTime.parse("01 Jan 2022") + 3.years }

              context "when it has not been billed yet" do
                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it has been billed" do
                before do
                  allow(subscription).to receive(:already_billed?).and_return(true)
                end

                it "returns true" do
                  expect(subject).to eq(true)
                end
              end
            end

            context "when it's not the first month in semiannual period" do
              let(:started_at) { DateTime.parse("01 Jan 2022") }
              let(:timestamp) { DateTime.parse("01 Feb 2022") + 3.years }

              context "when it has not been billed yet" do
                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it has been billed" do
                before do
                  allow(subscription).to receive(:already_billed?).and_return(true)
                end

                it "returns false" do
                  expect(subject).to eq(false)
                end
              end
            end
          end
        end

        context "when billing_time is anniversary" do
          let(:billing_time) { :anniversary }

          context "when subscription started in the past" do
            let(:created_at) { started_at + 1.month }

            context "when it's the first month in semiannual period" do
              context "when it is not the first month in first semiannual period" do
                let(:started_at) { DateTime.parse("01 Jun 2022") }
                let(:timestamp) { DateTime.parse("01 Jun 2022") + 3.years }

                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it is the first month in first semiannual period" do
                let(:timestamp) { DateTime.parse("01 Jun 2022") }
                let(:started_at) { DateTime.parse("01 Jun 2022") }

                it "returns false" do
                  expect(subject).to eq(false)
                end
              end
            end

            context "when it's not the first month in semiannual period" do
              let(:started_at) { DateTime.parse("01 Jun 2022") }
              let(:timestamp) { DateTime.parse("01 Jul 2022") + 3.years }

              it "returns false" do
                expect(subject).to eq(false)
              end
            end
          end

          context "when subscription did not start in the past" do
            context "when it's the first month in semiannual period" do
              let(:started_at) { DateTime.parse("01 Jun 2022") }
              let(:timestamp) { DateTime.parse("01 Jun 2022") + 3.years }

              context "when it has not been billed yet" do
                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it has been billed" do
                before do
                  allow(subscription).to receive(:already_billed?).and_return(true)
                end

                it "returns true" do
                  expect(subject).to eq(true)
                end
              end
            end

            context "when it's not the first month in semiannual period" do
              let(:started_at) { DateTime.parse("01 Jun 2022") }
              let(:timestamp) { DateTime.parse("01 Jul 2022") + 3.years }

              context "when it has not been billed yet" do
                it "returns true" do
                  expect(subject).to eq(true)
                end
              end

              context "when it has been billed" do
                before do
                  allow(subscription).to receive(:already_billed?).and_return(true)
                end

                it "returns false" do
                  expect(subject).to eq(false)
                end
              end
            end
          end
        end
      end
    end
  end
end
