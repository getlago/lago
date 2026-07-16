# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::FixedChargeService, :premium do
  subject(:fixed_charge_service) do
    described_class.new(invoice:, fixed_charge:, subscription:, boundaries:, context:, apply_taxes:)
  end

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }
  let(:context) { :finalize }
  let(:apply_taxes) { false }
  let(:started_at) { Time.zone.parse("2022-03-17") }

  let(:subscription) do
    create(
      :subscription,
      organization:,
      status: :active,
      started_at:,
      customer:
    )
  end

  let(:boundaries) do
    BillingPeriodBoundaries.new(
      from_datetime: subscription.started_at.to_date.beginning_of_day,
      to_datetime: subscription.started_at.end_of_month.end_of_day,
      charges_from_datetime: subscription.started_at.beginning_of_day,
      charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
      fixed_charges_from_datetime: subscription.started_at.beginning_of_day,
      fixed_charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
      timestamp: subscription.started_at.end_of_month.end_of_day + 1.second,
      charges_duration: (
        subscription.started_at.end_of_month.end_of_day - subscription.started_at.beginning_of_month
      ).fdiv(1.day).ceil,
      fixed_charges_duration: (
        subscription.started_at.end_of_month.end_of_day - subscription.started_at.beginning_of_month
      ).fdiv(1.day).ceil
    )
  end

  let(:invoice) do
    create(:invoice, :draft, customer:, organization:)
  end
  let(:fixed_charge) do
    create(
      :fixed_charge,
      plan: subscription.plan,
      charge_model: "standard",
      prorated: true,
      properties: {
        amount: "310"
      }
    )
  end
  let(:fixed_charge_tax) { create(:fixed_charge_applied_tax, fixed_charge:) }

  describe ".call" do
    context "with standard charge model" do
      it "creates a fee but does not persist it" do
        result = fixed_charge_service.call
        expect(result).to be_success
        expect(result.fee.id).to be_nil
        expect(result.fee.amount_cents).to eq(0)
      end

      context "with preview context and non-persisted subscription" do
        let(:context) { :invoice_preview }
        let(:subscription) do
          Subscription.new(
            organization_id: organization.id,
            customer:,
            plan: create(:plan, organization:),
            subscription_at: Time.current,
            started_at: Time.current,
            billing_time: "calendar"
          )
        end
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "standard",
            units: 8,
            properties: {amount: "12.5"}
          )
        end
        let(:invoice) { Invoice.new(customer:, organization:) }

        it "creates fee with default units from fixed_charge" do
          result = fixed_charge_service.call

          expect(result).to be_success
          expect(result.fee).to have_attributes(
            invoice: invoice,
            fixed_charge_id: fixed_charge.id,
            units: 8,
            amount_cents: 10000, # $12.5 * 8 units = $100
            precise_amount_cents: 10000.0
          )
        end
      end

      context "with an event" do
        context "when event created_at is within the current billing period" do
          let(:event) do
            create(
              :fixed_charge_event,
              organization: subscription.organization,
              subscription:,
              fixed_charge:,
              timestamp: boundaries.charges_to_datetime - 2.days,
              created_at: boundaries.charges_to_datetime - 2.days,
              units: 10
            )
          end

          before do
            event
            fixed_charge_tax
          end

          # 3 days proration out of 31 of 10 units with price 310 (310 * 3/31 * 10 = 300)
          it "creates a fee" do
            result = fixed_charge_service.call
            expect(result).to be_success
            prorated_units = (3.0 / 31 * 10).round(6)
            expect(result.fee).to have_attributes(
              id: String,
              organization_id: organization.id,
              billing_entity_id: invoice.customer.billing_entity_id,
              invoice_id: invoice.id,
              fixed_charge_id: fixed_charge.id,
              amount_cents: 30000,
              precise_amount_cents: 310_00 * prorated_units,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 10,
              unit_amount_cents: 3000,
              events_count: nil,
              payment_status: "pending"
            )
          end

          it "persists fee" do
            expect { fixed_charge_service.call }.to change(Fee, :count)
          end

          it "sets correct boundaries on the fee properties" do
            result = fixed_charge_service.call
            expect(result).to be_success
            expect(result.fee.properties).to include(
              "fixed_charges_from_datetime" => "2022-03-17T00:00:00.000Z",
              "fixed_charges_to_datetime" => "2022-03-31T23:59:59.999Z",
              "fixed_charges_duration" => 31,
              "charges_from_datetime" => nil,
              "charges_to_datetime" => nil,
              "charges_duration" => nil
            )
          end

          context "with preview context" do
            let(:context) { :invoice_preview }

            it "does not persist fee" do
              expect { fixed_charge_service.call }.not_to change(Fee, :count)
            end
          end

          context "with not prorated fixed_charge" do
            let(:fixed_charge) do
              create(:fixed_charge, plan: subscription.plan, charge_model: "standard", prorated: false, properties: {amount: "20"})
            end

            it "creates a fee" do
              result = fixed_charge_service.call
              expect(result).to be_success
              expect(result.fee).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                fixed_charge_id: fixed_charge.id,
                amount_cents: 20000,
                precise_amount_cents: 20000.0,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 10,
                unit_amount_cents: 2000,
                precise_unit_amount: 20,
                events_count: nil,
                payment_status: "pending"
              )
            end
          end

          context "when fixed charge is pay_in_advance" do
            let(:fixed_charge) do
              create(:fixed_charge, plan: subscription.plan, charge_model: "standard", pay_in_advance: true, properties: {amount: "10"})
            end

            it "sets boundaries of the next billing period" do
              result = fixed_charge_service.call
              expect(result).to be_success
              expect(result.fee.properties).to include(
                "fixed_charges_from_datetime" => "2022-04-01T00:00:00.000Z",
                "fixed_charges_to_datetime" => "2022-04-30T23:59:59.999Z",
                "fixed_charges_duration" => 30,
                "charges_from_datetime" => nil,
                "charges_to_datetime" => nil,
                "charges_duration" => nil
              )
            end
          end
        end

        context "with event created_at is after the current billing period" do
          let(:created_at) { Time.zone.parse("2022-05-17") }
          # NOTE: subscription started at 2022-03-17, so all charges only start from 17th
          let(:event) do
            create(:fixed_charge_event, fixed_charge:, subscription:, timestamp:, created_at:, units: 10)
          end

          before do
            event
          end

          context "when event timestamp is before the current billing period" do
            let(:timestamp) { Time.zone.parse("2022-01-17") }

            # subscription started at 2022-03-17, so all charges only start from 17th => 15 days
            it "finds the event and creates the fee with proration from the beginning of the billing period" do
              result = fixed_charge_service.call
              expect(result).to be_success
              expect(result.fee).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                fixed_charge_id: fixed_charge.id,
                amount_cents: 150000,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 10,
                unit_amount_cents: 15000,
                events_count: nil,
                payment_status: "pending"
              )
            end
          end

          context "when event timestamp is within the current billing period" do
            let(:timestamp) { Time.zone.parse("2022-03-22") }

            # 10 days proration
            # 10 days proration out of 31 of 10 units with price 310 (310 * 10/31 * 10 = 1000)
            it "finds the event and creates the fee with the correct amount" do
              result = fixed_charge_service.call
              expect(result).to be_success
              expect(result.fee).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                fixed_charge_id: fixed_charge.id,
                amount_cents: 100000,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 10,
                # the math here is broken because of rounding. Firstly we're calculating the proration: 10/31 = 0.3225806451612903 => 0.322580
                # then we're multiplying by the price: 3.225806 * 31000 = 9999,98 => 9999
                unit_amount_cents: 9999,
                events_count: nil,
                payment_status: "pending"
              )
            end
          end

          context "when event timestamp is after the current billing period" do
            let(:timestamp) { Time.zone.parse("2022-04-20") }

            it "does not find the event and returns an empty fee" do
              result = fixed_charge_service.call
              expect(result).to be_success
              expect(result.fee).to be_present
              expect(result.fee.amount_cents).to eq(0)
              expect(result.fee.id).to be_nil
            end
          end
        end
      end
    end

    context "with graduated charge model" do
      let(:fixed_charge) do
        create(
          :fixed_charge,
          plan: subscription.plan,
          charge_model: "graduated",
          prorated: false,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: 5,
                per_unit_amount: "0.1",
                flat_amount: "10"
              },
              {
                from_value: 6,
                to_value: nil,
                per_unit_amount: "2",
                flat_amount: "20"
              }
            ]
          }
        )
      end

      before do
        create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: boundaries.from_datetime + 5.days, units: 62, created_at: boundaries.from_datetime + 5.days)
        create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: boundaries.from_datetime + 10.days, units: 3.1, created_at: boundaries.from_datetime + 10.days)
      end

      # this is not prorated result!
      it "creates a fee" do
        result = fixed_charge_service.call
        expect(result).to be_success
        expect(result.fee).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          fixed_charge_id: fixed_charge.id,
          amount_cents: 1031,
          precise_amount_cents: 1031.0,
          taxes_precise_amount_cents: 0.0,
          amount_currency: "EUR",
          units: 3.1,
          unit_amount_cents: 332,
          precise_unit_amount: (10.31 / 3.1),
          events_count: nil
        )
      end

      context "with prorated fixed_charge" do
        let(:fixed_charge) do
          create(
            :fixed_charge,
            plan: subscription.plan,
            charge_model: "graduated",
            prorated: true,
            properties: {
              graduated_ranges: [
                {
                  from_value: 0,
                  to_value: 5,
                  per_unit_amount: "0.1",
                  flat_amount: "10"
                },
                {
                  from_value: 6,
                  to_value: nil,
                  per_unit_amount: "2",
                  flat_amount: "20"
                }
              ]
            }
          )
        end

        it "creates a fee" do
          result = fixed_charge_service.call
          expect(result).to be_success
          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            fixed_charge_id: fixed_charge.id,
            amount_cents: 1105,
            precise_amount_cents: 1105.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 3.1,
            unit_amount_cents: 356,
            events_count: nil
          )
        end
      end
    end

    context "with volume charge model" do
      let(:fixed_charge) do
        create(:fixed_charge,
          plan: subscription.plan,
          charge_model: "volume",
          prorated: false,
          properties: {
            volume_ranges: [
              {
                from_value: 0,
                to_value: 10,
                per_unit_amount: "0.1",
                flat_amount: "10"
              },
              {
                from_value: 11,
                to_value: nil,
                per_unit_amount: "2",
                flat_amount: "20"
              }
            ]
          })
      end

      before do
        create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: boundaries.from_datetime + 5.days, units: 31, created_at: boundaries.from_datetime + 5.days)
        create(:fixed_charge_event, fixed_charge:, subscription:, timestamp: boundaries.from_datetime + 10.days, units: 3.1, created_at: boundaries.from_datetime + 10.days)
      end

      it "creates a fee" do
        result = fixed_charge_service.call
        expect(result).to be_success
        expect(result.fee).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          fixed_charge_id: fixed_charge.id,
          amount_cents: 1031,
          precise_amount_cents: 1031.0,
          taxes_precise_amount_cents: 0.0,
          amount_currency: "EUR",
          units: 3.1,
          unit_amount_cents: 332,
          precise_unit_amount: 10.31 / 3.1,
          events_count: nil
        )
      end

      context "with prorated fixed_charge" do
        let(:fixed_charge) do
          create(:fixed_charge,
            plan: subscription.plan,
            charge_model: "volume",
            prorated: true,
            properties: {
              volume_ranges: [
                {
                  from_value: 0,
                  to_value: 10,
                  per_unit_amount: "0.1",
                  flat_amount: "10"
                },
                {
                  from_value: 11,
                  to_value: nil,
                  per_unit_amount: "2",
                  flat_amount: "20"
                }
              ]
            })
        end

        it "creates a fee" do
          result = fixed_charge_service.call
          expect(result).to be_success
          # (31 * 5 / 31.0 + 3.1 * 5 / 31.0).round(6)
          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            fixed_charge_id: fixed_charge.id,
            amount_cents: 1000 + (10 * 5.5),
            precise_amount_cents: 1055.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 3.1,
            unit_amount_cents: 340,
            precise_unit_amount: 10.55 / 3.1,
            events_count: nil
          )
        end
      end
    end

    context "when fee already exists on the period" do
      before do
        create(:fee, fixed_charge:, subscription:, invoice:)
      end

      it "does not create a new fee" do
        expect { fixed_charge_service.call }.not_to change(Fee, :count)
      end
    end

    context "when billing a new upgraded subscription" do
      let(:previous_plan) { create(:plan, amount_cents: subscription.plan.amount_cents - 20) }
      let(:fixed_charge) do
        create(:fixed_charge, plan: subscription.plan, charge_model: "standard", prorated: true, properties: {amount: "30"})
      end
      let(:previous_subscription) do
        create(:subscription, plan: previous_plan, status: :terminated)
      end

      let(:event) do
        create(
          :fixed_charge_event,
          organization: invoice.organization,
          subscription:,
          fixed_charge:,
          timestamp: Time.zone.parse("10 Apr 2022 00:01:00"),
          units: 10
        )
      end

      let(:started_at) { Time.zone.parse("2022-04-17") }

      let(:subscription) do
        create(
          :subscription,
          organization:,
          status: :active,
          started_at:,
          customer:
        )
      end

      let(:boundaries) do
        BillingPeriodBoundaries.new(
          from_datetime: started_at,
          to_datetime: started_at.end_of_month,
          charges_from_datetime: started_at,
          charges_to_datetime: started_at.end_of_month,
          fixed_charges_from_datetime: started_at,
          fixed_charges_to_datetime: started_at.end_of_month,
          charges_duration: 30,
          fixed_charges_duration: 30,
          timestamp: Time.zone.parse("2022-05-01T00:00:00.000Z")
        )
      end

      before do
        subscription.update!(previous_subscription:)
        event
      end

      # proration starts on 17th of April, so 14 days proration
      it "creates a new prorated fee for the complete period" do
        result = fixed_charge_service.call
        expect(result).to be_success
        expect(result.fee).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          fixed_charge_id: fixed_charge.id,
          amount_cents: 14000,
          taxes_precise_amount_cents: 0.0,
          amount_currency: "EUR",
          units: 10
        )
      end

      context "when there is an already paid fee from prev subscription" do
        context "when fee is paid in advance" do
          let(:pay_in_advance) { true }
          let(:previous_fixed_charge) do
            create(:fixed_charge, plan: previous_plan, charge_model: "standard", prorated: true, properties: {amount: prev_price}, add_on: fixed_charge.add_on, pay_in_advance:)
          end
          let(:previous_fee) do
            create(:fee, fixed_charge: previous_fixed_charge, subscription: previous_subscription,
              properties: previous_boundaries.to_h, amount_cents: prev_fee_price, organization:,
              billing_entity: subscription.customer.billing_entity)
          end
          let(:previous_timestamp) { Time.zone.parse("11 Apr 2022 00:01:00") }
          let(:previous_boundaries) do
            BillingPeriodBoundaries.new(
              from_datetime: previous_timestamp,
              to_datetime: started_at.end_of_month,
              charges_from_datetime: previous_timestamp,
              charges_to_datetime: started_at.end_of_month,
              fixed_charges_from_datetime: previous_timestamp,
              fixed_charges_to_datetime: started_at.end_of_month,
              charges_duration: 30,
              fixed_charges_duration: 30,
              timestamp: previous_timestamp
            )
          end

          let(:fixed_charge) do
            create(:fixed_charge, plan: subscription.plan, charge_model: "standard", prorated: true, properties: {amount: new_price}, pay_in_advance:)
          end
          let(:boundaries) do
            BillingPeriodBoundaries.new(
              from_datetime: started_at,
              to_datetime: started_at,
              charges_from_datetime: started_at,
              charges_to_datetime: started_at,
              fixed_charges_from_datetime: started_at,
              fixed_charges_to_datetime: started_at,
              charges_duration: 30,
              fixed_charges_duration: 30,
              timestamp: Time.zone.parse("2022-04-17T00:01:00.000Z")
            )
          end

          before { previous_fee }

          context "when fixed charge price is higher than previous one" do
            let(:prev_price) { "3" }
            let(:prev_fee_price) { 2000 } # (for 20 days out of 30)
            let(:new_price) { "60" }

            it "creates a new prorated fee for the complete period" do
              result = fixed_charge_service.call
              expect(result).to be_success
              expect(result.fee).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                fixed_charge_id: fixed_charge.id,
                # new_proration = 6000 * 14 / 30 * 10
                # previous_proration = 2000 (for 20 days)
                # total = new_proration - previous_proration * 14 / 20 = 28000 - 1400 = 26600
                amount_cents: 26600,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 10
              )
            end

            context "when previous fee was issued during the billing period" do
              let(:previous_boundaries) do
                BillingPeriodBoundaries.new(
                  from_datetime: previous_timestamp.beginning_of_month,
                  to_datetime: started_at.end_of_month,
                  charges_from_datetime: previous_timestamp.beginning_of_month,
                  charges_to_datetime: started_at.end_of_month,
                  fixed_charges_from_datetime: previous_timestamp.beginning_of_month,
                  fixed_charges_to_datetime: started_at.end_of_month,
                  charges_duration: 30,
                  fixed_charges_duration: 30,
                  timestamp: previous_timestamp
                )
              end

              it "calculate correct proration for the previous fee" do
                result = fixed_charge_service.call
                expect(result).to be_success
                expect(result.fee).to have_attributes(
                  id: String,
                  invoice_id: invoice.id,
                  fixed_charge_id: fixed_charge.id,
                  amount_cents: 26600
                )
              end
            end
          end

          context "when fixed charge price is lower than previous one" do
            let(:prev_price) { "60" }
            let(:prev_fee_price) { 40000 } # (for 20 days out of 30, 10 units)
            let(:new_price) { "30" }

            it "creates a new prorated fee for the complete period" do
              result = fixed_charge_service.call
              expect(result).to be_success
              expect(result.fee).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                fixed_charge_id: fixed_charge.id,
                amount_cents: 0,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 10
              )
            end
          end
        end
      end
    end

    context "when applying taxes" do
      let(:apply_taxes) { true }
      let(:event) do
        create(
          :fixed_charge_event,
          organization: subscription.organization,
          subscription:,
          fixed_charge:,
          timestamp: boundaries.charges_to_datetime - 2.days,
          units: 10
        )
      end

      before do
        event
        fixed_charge_tax
      end

      # 3 days proration out of 31 of 10 units with price 310 (310 * 3/31 * 10 = 300)
      it "creates a fee with taxes" do
        result = fixed_charge_service.call
        expect(result).to be_success
        expect(result.fee).to have_attributes(
          taxes_amount_cents: 30000 * fixed_charge_tax.tax.rate / 100
        )
      end
    end

    context "when fixed charge is pay_in_advance" do
      let(:fixed_charge) do
        create(:fixed_charge, plan: subscription.plan, charge_model: "standard", pay_in_advance: true, properties: {amount: "10"})
      end

      it "creates a fee with pay_in_advance boundaries" do
        result = fixed_charge_service.call
        expect(result).to be_success
        expect(result.fee.properties).to include(
          "fixed_charges_from_datetime" => Time.parse("2022-04-01T00:00:00.000Z"),
          "fixed_charges_to_datetime" => Time.parse("2022-04-30T23:59:59.999Z"),
          "fixed_charges_duration" => 30
        )
      end
    end

    context "when fixed charge is not pay_in_advance" do
      let(:fixed_charge) do
        create(:fixed_charge, plan: subscription.plan, charge_model: "standard", pay_in_advance: false, properties: {amount: "10"})
      end

      it "creates a fee with current boundaries" do
        result = fixed_charge_service.call
        expect(result).to be_success
        # subscription started at 2022-03-17, so all charges only start from 17th
        expect(result.fee.properties).to include(
          "fixed_charges_from_datetime" => Time.parse("2022-03-17T00:00:00.000Z"),
          "fixed_charges_to_datetime" => Time.parse("2022-03-31T23:59:59.999Z"),
          "fixed_charges_duration" => 31
        )
      end
    end

    context "when there is an adjusted fee for fixed charge" do
      let(:event) do
        create(
          :fixed_charge_event,
          organization:,
          subscription:,
          fixed_charge:,
          timestamp: boundaries.charges_to_datetime - 2.days,
          units: 10
        )
      end

      let(:adjusted_fee) do
        create(
          :adjusted_fee,
          invoice:,
          subscription:,
          fixed_charge:,
          properties:,
          fee_type: :fixed_charge,
          adjusted_units: true,
          adjusted_amount: false,
          units: 5
        )
      end

      let(:properties) do
        {
          fixed_charges_from_datetime: boundaries.fixed_charges_from_datetime,
          fixed_charges_to_datetime: boundaries.fixed_charges_to_datetime
        }
      end

      before do
        event
        adjusted_fee
      end

      context "with adjusted units" do
        it "creates a fee with adjusted units" do
          result = fixed_charge_service.call

          expect(result).to be_success
          expect(result.fee).to have_attributes(
            id: String,
            invoice:,
            fixed_charge:,
            amount_cents: 155_000,
            precise_amount_cents: 155_000,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 5,
            unit_amount_cents: 31_000,
            precise_unit_amount: 310,
            payment_status: "pending"
          )
        end

        it "updates the adjusted fee with the new fee_id" do
          result = fixed_charge_service.call

          expect(result).to be_success
          expect(adjusted_fee.reload.fee_id).to eq(result.fee.id)
        end
      end

      context "with adjusted amount" do
        let(:adjusted_fee) do
          create(
            :adjusted_fee,
            invoice:,
            subscription:,
            fixed_charge:,
            properties:,
            fee_type: :fixed_charge,
            adjusted_units: false,
            adjusted_amount: true,
            units: 10,
            unit_amount_cents: 500,
            unit_precise_amount_cents: 500
          )
        end

        it "creates a fee with adjusted amount" do
          result = fixed_charge_service.call

          expect(result).to be_success
          expect(result.fee).to have_attributes(
            id: String,
            invoice:,
            fixed_charge:,
            amount_cents: 5_000,
            precise_amount_cents: 5_000.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 10,
            unit_amount_cents: 500,
            precise_unit_amount: 5,
            payment_status: "pending"
          )
        end
      end

      context "with adjusted display name only" do
        let(:adjusted_fee) do
          create(
            :adjusted_fee,
            invoice:,
            subscription:,
            fixed_charge:,
            properties:,
            fee_type: :fixed_charge,
            adjusted_units: false,
            adjusted_amount: false,
            invoice_display_name: "Custom Fixed Charge Name",
            units: 5
          )
        end

        it "creates a fee with adjusted display name" do
          result = fixed_charge_service.call

          expect(result).to be_success
          expect(result.fee).to have_attributes(
            id: String,
            invoice:,
            fixed_charge:,
            amount_cents: 30_000,
            precise_amount_cents: 30_000.002,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 10,
            unit_amount_cents: 3_000,
            precise_unit_amount: 30.000002,
            invoice_display_name: "Custom Fixed Charge Name",
            payment_status: "pending"
          )
        end
      end

      context "with adjusted units set to zero" do
        let(:adjusted_fee) do
          create(
            :adjusted_fee,
            invoice:,
            subscription:,
            fixed_charge:,
            properties:,
            fee_type: :fixed_charge,
            adjusted_units: true,
            adjusted_amount: false,
            units: 0
          )
        end

        it "creates and persists a fee with zero units" do
          result = fixed_charge_service.call

          expect(result).to be_success
          expect(result.fee).to have_attributes(
            id: String,
            invoice:,
            fixed_charge:,
            amount_cents: 0,
            precise_amount_cents: 0.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 0,
            payment_status: "pending"
          )
          # Fee should be persisted despite zero units
          expect(result.fee.persisted?).to be(true)
        end

        it "updates the adjusted fee with the new fee_id" do
          result = fixed_charge_service.call

          expect(result).to be_success
          expect(adjusted_fee.reload.fee_id).to eq(result.fee.id)
        end
      end

      context "with invoice NOT in draft status" do
        before { invoice.finalized! }

        it "creates a fee without using adjusted fee attributes" do
          result = fixed_charge_service.call

          expect(result).to be_success
          expect(result.fee).to have_attributes(
            id: String,
            invoice:,
            fixed_charge:,
            amount_cents: 30_000,
            precise_amount_cents: 30_000.002,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 10,
            unit_amount_cents: 3_000,
            precise_unit_amount: 30.000002,
            payment_status: "pending"
          )
        end
      end
    end
  end
end
