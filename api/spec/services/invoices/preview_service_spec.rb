# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::PreviewService, cache: :memory do
  subject(:preview_service) { described_class.new(customer:, subscriptions:) }

  describe "#call" do
    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:tax) { create(:tax, :applied_to_billing_entity, rate: 50.0, organization:, billing_entity:) }
    let(:customer) { build(:customer, organization:, billing_entity:) }
    let(:timestamp) { Time.zone.parse("30 Mar 2024") }
    let(:plan) { create(:plan, organization:, interval: "monthly") }
    let(:billing_time) { "calendar" }
    let(:subscriptions) { [subscription] }
    let(:subscription) do
      build(
        :subscription,
        customer:,
        plan:,
        billing_time:,
        subscription_at: timestamp,
        started_at: timestamp,
        created_at: timestamp
      )
    end

    before { tax }

    context "with Lago freemium" do
      it "returns a failure" do
        travel_to(timestamp) do
          result = preview_service.call

          expect(result).not_to be_success

          expect(result.error).to be_a(BaseService::ForbiddenFailure)
          expect(result.error.code).to eq("feature_unavailable")
        end
      end
    end

    context "with Lago premium", :premium do
      context "when customer does not exist" do
        it "returns an error" do
          result = described_class.new(customer: nil, subscriptions: [subscription]).call

          expect(result).not_to be_success
          expect(result.error.error_code).to eq("customer_not_found")
        end
      end

      context "when subscriptions are missing" do
        let(:subscriptions) { [] }

        it "returns an error" do
          result = preview_service.call

          expect(result).not_to be_success
          expect(result.error.error_code).to eq("subscription_not_found")
        end
      end

      context "when currencies do not match" do
        let(:customer) { build(:customer, organization:, billing_entity:, currency: "USD") }

        it "returns an error" do
          result = preview_service.call

          expect(result).not_to be_success
          expect(result.error.messages[:base]).to include("customer_currency_does_not_match")
        end

        context "when multi_currency flag is enabled" do
          before { organization.enable_feature_flag!(:multi_currency) }

          it "allows the preview" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice).to be_present
            end
          end
        end
      end

      context "with multi-entity billing" do
        let(:other_billing_entity) { create(:billing_entity, organization:) }

        context "when multi_entity_billing flag is disabled" do
          let(:subscription) do
            build(
              :subscription,
              customer:,
              plan:,
              billing_entity: other_billing_entity,
              billing_time:,
              subscription_at: timestamp,
              started_at: timestamp,
              created_at: timestamp
            )
          end

          it "ignores the subscription's billing entity and uses the customer's entity" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.billing_entity).to eq(billing_entity)
            end
          end
        end

        context "when multi_entity_billing flag is enabled" do
          before { organization.enable_feature_flag!(:multi_entity_billing) }

          context "when the subscription has its own billing entity" do
            let(:subscription) do
              build(
                :subscription,
                customer:,
                plan:,
                billing_entity: other_billing_entity,
                billing_time:,
                subscription_at: timestamp,
                started_at: timestamp,
                created_at: timestamp
              )
            end

            it "uses the subscription's billing entity" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.billing_entity).to eq(other_billing_entity)
              end
            end
          end

          context "when the subscription has no explicit billing entity" do
            it "falls back to the customer's billing entity" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.billing_entity).to eq(billing_entity)
              end
            end
          end

          context "when subscriptions have mismatched effective billing entities" do
            let(:customer) { create(:customer, organization:, billing_entity:) }
            let(:plan1) { create(:plan, organization:, interval: "monthly") }
            let(:plan2) { create(:plan, organization:, interval: "monthly") }
            let(:subscriptions) { [subscription1, subscription2] }
            let(:subscription1) do
              create(:subscription, plan: plan1, customer:, billing_entity:, subscription_at: timestamp, billing_time: "calendar")
            end
            let(:subscription2) do
              create(:subscription, plan: plan2, customer:, billing_entity: other_billing_entity, subscription_at: timestamp, billing_time: "calendar")
            end

            before { organization.update!(premium_integrations: ["preview"]) }

            it "returns a validation error" do
              result = preview_service.call

              expect(result).not_to be_success
              expect(result.error.messages[:base]).to include("subscription_billing_entities_do_not_match")
            end
          end
        end
      end

      context "when billing periods do not match" do
        let(:customer) { create(:customer, organization:, billing_entity:) }
        let(:plan1) { create(:plan, organization:, interval: "monthly") }
        let(:plan2) { create(:plan, organization:, interval: "monthly") }
        let(:subscriptions) { [subscription1, subscription2] }
        let(:subscription1) do
          create(:subscription, plan: plan1, customer:, subscription_at: Time.current.beginning_of_month - 10.days, billing_time: "anniversary")
        end
        let(:subscription2) do
          create(:subscription, plan: plan2, customer:, subscription_at: Time.current.beginning_of_month - 9.days, billing_time: "anniversary")
        end

        before { organization.update!(premium_integrations: ["preview"]) }

        it "returns an error" do
          result = preview_service.call

          expect(result).not_to be_success
          expect(result.error.messages[:base]).to include("billing_periods_does_not_match")
        end
      end

      context "with calendar billing" do
        it "creates preview invoice for 2 days" do
          # Two days should be billed, Mar 30 and Mar 31

          travel_to(timestamp) do
            result = preview_service.call

            expect(result).to be_success
            expect(result.invoice.organization).to eq(organization)
            expect(result.invoice.billing_entity).to eq(customer.billing_entity)
            expect(result.invoice.subscriptions.first).to eq(subscription)
            expect(result.invoice.fees.length).to eq(1)
            expect(result.invoice.invoice_type).to eq("subscription")
            expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
            expect(result.invoice.fees_amount_cents).to eq(6)
            expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(6)
            expect(result.invoice.taxes_amount_cents).to eq(3)
            expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(9)
            expect(result.invoice.total_amount_cents).to eq(9)
          end
        end

        context "with fixed charges for non-persisted subscription" do
          let(:add_on) { create(:add_on, organization:) }

          context "with pay in adavnace and standard charge model" do
            let(:fixed_charge) do
              create(
                :fixed_charge,
                plan:,
                add_on:,
                charge_model: "standard",
                pay_in_advance: true,
                units: 3,
                properties: {amount: "15"}
              )
            end

            before { fixed_charge }

            it "creates preview invoice with fixed charges using default units" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.fees.size).to eq(2) # subscription + fixed_charge

                fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                expect(fixed_charge_fees.size).to eq(1)

                fixed_charge_fee = fixed_charge_fees.first
                expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge)
                expect(fixed_charge_fee.units).to eq(3)
                expect(fixed_charge_fee.amount_cents).to eq(4500) # $15 * 3 units = $45

                # Total: subscription (6) + fixed charge (4500) = 4506
                expect(result.invoice.fees_amount_cents).to eq(4506)
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(4506)
                expect(result.invoice.taxes_amount_cents).to eq(2253) # 50% tax
                expect(result.invoice.total_amount_cents).to eq(6759)
              end
            end
          end

          context "with volume charge model (pay_in_arrears)" do
            let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: false) }
            let(:fixed_charge) do
              create(
                :fixed_charge,
                plan:,
                add_on:,
                charge_model: "volume",
                pay_in_advance: false,
                units: 18,
                properties: {
                  volume_ranges: [
                    {from_value: 0, to_value: 10, flat_amount: "0", per_unit_amount: "3"},
                    {from_value: 11, to_value: 50, flat_amount: "15", per_unit_amount: "2"},
                    {from_value: 51, to_value: nil, flat_amount: "30", per_unit_amount: "1"}
                  ]
                }
              )
            end

            before { fixed_charge }

            it "includes volume charge for non-persisted subscription" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.fees.size).to eq(2) # subscription + fixed_charge

                fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                expect(fixed_charge_fees.size).to eq(1)

                fixed_charge_fee = fixed_charge_fees.first
                expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge)
                expect(fixed_charge_fee.units).to eq(18)
                # 18 units falls in second tier: $15 flat + (18 * $2) = $51
                expect(fixed_charge_fee.amount_cents).to eq(5100)
              end
            end
          end

          context "with pay_in_arrears fixed charge" do
            let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: false) }
            let(:fixed_charge) do
              create(
                :fixed_charge,
                plan:,
                add_on:,
                charge_model: "standard",
                pay_in_advance: false,
                units: 5,
                properties: {amount: "20"}
              )
            end

            before { fixed_charge }

            it "includes pay_in_arrears fixed charge for non-persisted subscription" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.fees.size).to eq(2) # subscription + fixed_charge

                fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                expect(fixed_charge_fees.size).to eq(1)

                fixed_charge_fee = fixed_charge_fees.first
                expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge)
                expect(fixed_charge_fee.units).to eq(5)
                expect(fixed_charge_fee.amount_cents).to eq(10000) # $20 * 5 units = $100

                # Total: subscription fee + fixed charge
                expect(result.invoice.fees_amount_cents).to eq(10006)
              end
            end
          end

          context "with prorated fixed charge" do
            let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: true) }
            let(:timestamp) { Time.zone.parse("15 Mar 2024") } # Mid-month start
            let(:subscription) do
              build(
                :subscription,
                customer:,
                plan:,
                billing_time: "calendar",
                subscription_at: timestamp,
                started_at: timestamp,
                created_at: timestamp
              )
            end
            let(:fixed_charge) do
              create(
                :fixed_charge,
                plan:,
                add_on:,
                charge_model: "standard",
                prorated: true,
                pay_in_advance: true,
                units: 100,
                properties: {amount: "10"}
              )
            end

            before { fixed_charge }

            it "prorates fixed charge based on billing period" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success

                fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                expect(fixed_charge_fees.size).to eq(1)

                fixed_charge_fee = fixed_charge_fees.first
                # Units remain full value (100) - proration happens to amount
                expect(fixed_charge_fee.units).to eq(100)
                expect(fixed_charge_fee.amount_cents).to eq(54_839)
              end
            end
          end
        end

        context "with minimum commitment for non-persisted subscription" do
          let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: false, amount_cents: 0) }
          let!(:commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_00) }

          before { organization.update!(premium_integrations: ["preview"]) }

          it "includes a non-persisted commitment fee" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success

              commitment_fees = result.invoice.fees.select { |f| f.fee_type == "commitment" }
              expect(commitment_fees.size).to eq(1)

              commitment_fee = commitment_fees.first
              expect(commitment_fee).not_to be_persisted
              expect(commitment_fee.invoiceable_id).to eq(commitment.id)
              # calendar billing: subscription started Mar 30, so days_active starts from Mar 30, not Jan 1
              # days_active = 277 (Mar 30 => Dec 31), days_total = 366 (Jan 1 => Dec 31, 2024 leap year)
              # proration = 277 / 366.0 => (100_000 * 0.7568...).round = 75_683
              expect(commitment_fee.amount_cents).to eq(75_683)
            end
          end
        end

        context "with one persisted subscription" do
          let(:customer) { create(:customer, organization:, billing_entity:) }
          let(:subscription) do
            create(
              :subscription,
              customer:,
              plan:,
              billing_time:,
              subscription_at: timestamp,
              started_at: timestamp,
              created_at: timestamp
            )
          end

          before { organization.update!(premium_integrations: ["preview"]) }

          it "creates preview invoice for 2 days" do
            # Two days should be billed, Mar 30 and Mar 31

            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.first).to eq(subscription)
              expect(result.invoice.fees.length).to eq(1)
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
              expect(result.invoice.fees_amount_cents).to eq(6)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(6)
              expect(result.invoice.taxes_amount_cents).to eq(3)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(9)
              expect(result.invoice.total_amount_cents).to eq(9)
            end
          end

          context "with charge fees" do
            let(:billable_metric) do
              create(:billable_metric, aggregation_type: "count_agg")
            end
            let(:charge) do
              create(
                :standard_charge,
                plan:,
                billable_metric:,
                properties: {amount: "12.66"}
              )
            end
            let(:events) do
              create_list(
                :event,
                2,
                organization:,
                subscription:,
                customer:,
                code: billable_metric.code,
                timestamp: timestamp + 10.hours
              )
            end

            before do
              events if subscription
              charge
              Rails.cache.clear
            end

            it "creates preview invoice for 2 days", transaction: false do
              # Two days should be billed, Mar 30 and Mar 31

              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.organization).to eq(organization)
                expect(result.invoice.billing_entity).to eq(customer.billing_entity)
                expect(result.invoice.subscriptions.first).to eq(subscription)
                expect(result.invoice.fees.length).to eq(2)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
                expect(result.invoice.fees_amount_cents).to eq(2538) # 6.45 + 1266 x 2 = 2538
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(2538)
                expect(result.invoice.taxes_amount_cents).to eq(1269) # 1269
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(3807) # 3807
                expect(result.invoice.total_amount_cents).to eq(3807) # 3807
              end
            end

            it "uses the Rails cache", transaction: false do
              key = [
                "charge-usage",
                Subscriptions::ChargeCacheService::CACHE_KEY_VERSION,
                charge.id,
                subscription.id,
                charge.updated_at.iso8601
              ].join("/")

              expect do
                preview_service.call
              end.to change { Rails.cache.exist?(key) }.from(false).to(true)
            end
          end

          context "with fixed charges" do
            let(:add_on) { create(:add_on, organization:) }

            context "with pay_in_advance fixed charge on first invoice" do
              let(:fixed_charge) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on:,
                  charge_model: "standard",
                  pay_in_advance: true,
                  prorated: false,
                  units: 2,
                  properties: {amount: "10"}
                )
              end

              before do
                fixed_charge
                event_timestamp = subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription:,
                  fixed_charge:,
                  units: fixed_charge.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )
              end

              it "includes pay_in_advance fixed charge on first invoice" do
                travel_to(timestamp) do
                  result = preview_service.call

                  expect(result).to be_success
                  expect(result.invoice.fees.size).to eq(2) # subscription + fixed_charge

                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  expect(fixed_charge_fees.size).to eq(1)

                  fixed_charge_fee = fixed_charge_fees.first
                  expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge)
                  expect(fixed_charge_fee.amount_cents).to eq(2000) # $10 * 2 units * 100
                  expect(fixed_charge_fee.units).to eq(2)

                  # Total: subscription (6) + fixed charge (2000) = 2006
                  expect(result.invoice.fees_amount_cents).to eq(2006)
                  expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(2006)
                  expect(result.invoice.taxes_amount_cents).to eq(1003) # 50% tax
                  expect(result.invoice.total_amount_cents).to eq(3009)
                end
              end
            end

            context "with pay_in_arrears fixed charge on first invoice" do
              let(:fixed_charge) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on:,
                  charge_model: "standard",
                  pay_in_advance: false,
                  prorated: false,
                  units: 1,
                  properties: {amount: "5"}
                )
              end

              before do
                fixed_charge

                # Create invoice_subscription to mark this as "starting"
                create(
                  :invoice_subscription,
                  subscription:,
                  invoicing_reason: :subscription_starting,
                  from_datetime: subscription.started_at,
                  to_datetime: subscription.started_at + 1.month
                )
              end

              it "does not include pay_in_arrears fixed charge on first invoice" do
                travel_to(timestamp) do
                  result = preview_service.call

                  expect(result).to be_success
                  expect(result.invoice.fees.size).to eq(1) # only subscription fee

                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  expect(fixed_charge_fees.size).to be_zero

                  # Only subscription fee
                  expect(result.invoice.fees_amount_cents).to eq(6)
                end
              end
            end

            context "with pay_in_arrears fixed charge on subsequent invoice" do
              let(:fixed_charge) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on:,
                  charge_model: "standard",
                  pay_in_advance: false,
                  prorated: false,
                  units: 1,
                  properties: {amount: "5"}
                )
              end

              before do
                fixed_charge

                event_timestamp = subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription:,
                  fixed_charge:,
                  units: fixed_charge.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )

                # Create invoice_subscriptions to simulate that subscription has been invoiced before
                # First invoice (subscription_starting)
                create(
                  :invoice_subscription,
                  subscription:,
                  invoicing_reason: :subscription_starting,
                  from_datetime: subscription.started_at,
                  to_datetime: subscription.started_at + 1.month,
                  created_at: 1.month.ago
                )

                # Second invoice (regular billing)
                create(
                  :invoice_subscription,
                  subscription:,
                  invoicing_reason: :subscription_periodic,
                  from_datetime: subscription.started_at + 1.month,
                  to_datetime: subscription.started_at + 2.months,
                  created_at: 15.days.ago
                )
              end

              it "includes pay_in_arrears fixed charge on subsequent invoice" do
                travel_to(timestamp + 1.month) do
                  result = preview_service.call

                  expect(result).to be_success
                  expect(result.invoice.fees.size).to eq(2) # subscription + fixed_charge

                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  expect(fixed_charge_fees.size).to eq(1)

                  fixed_charge_fee = fixed_charge_fees.first
                  expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge)
                  expect(fixed_charge_fee.amount_cents).to eq(500) # $5 * 1 unit * 100
                end
              end
            end

            context "with multiple fixed charges" do
              let(:add_on2) { create(:add_on, organization:) }
              let(:add_on3) { create(:add_on, organization:) }

              let(:fixed_charge_advance) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on:,
                  charge_model: "standard",
                  pay_in_advance: true,
                  units: 1,
                  properties: {amount: "10"}
                )
              end
              let(:fixed_charge_advance2) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on: add_on2,
                  charge_model: "standard",
                  pay_in_advance: true,
                  units: 2,
                  properties: {amount: "5"}
                )
              end
              let(:fixed_charge_in_arrears) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on: add_on3,
                  charge_model: "standard",
                  pay_in_advance: false,
                  units: 1,
                  properties: {amount: "25"}
                )
              end

              before do
                fixed_charge_advance
                fixed_charge_advance2
                fixed_charge_in_arrears

                event_timestamp = subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription:,
                  fixed_charge: fixed_charge_advance,
                  units: fixed_charge_advance.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )

                create(
                  :fixed_charge_event,
                  organization:,
                  subscription:,
                  fixed_charge: fixed_charge_advance2,
                  units: fixed_charge_advance2.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )

                create(
                  :fixed_charge_event,
                  organization:,
                  subscription:,
                  fixed_charge: fixed_charge_in_arrears,
                  units: fixed_charge_in_arrears.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )
              end

              it "includes all applicable fixed charges" do
                travel_to(timestamp) do
                  result = preview_service.call

                  expect(result).to be_success

                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  expect(fixed_charge_fees.size).to eq(3)

                  total_fixed_charges = fixed_charge_fees.sum(&:amount_cents)
                  expect(total_fixed_charges).to eq(4500) # $10 * 1 + $5 * 2 + $25 * 1 = $45

                  # Total: subscription (6) + fixed charges (4500) = 4506
                  expect(result.invoice.fees_amount_cents).to eq(4506)
                end
              end
            end

            context "with graduated pricing model" do
              let(:fixed_charge) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on:,
                  charge_model: "graduated",
                  pay_in_advance: true,
                  units: 15,
                  properties: {
                    graduated_ranges: [
                      {from_value: 0, to_value: 10, flat_amount: "0", per_unit_amount: "1"},
                      {from_value: 11, to_value: nil, flat_amount: "0", per_unit_amount: "0.5"}
                    ]
                  }
                )
              end

              before do
                fixed_charge

                event_timestamp = subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription:,
                  fixed_charge:,
                  units: fixed_charge.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )
              end

              it "calculates graduated pricing correctly" do
                travel_to(timestamp) do
                  result = preview_service.call

                  expect(result).to be_success

                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  fixed_charge_fee = fixed_charge_fees.first
                  # 10 units * $1 + 5 units * $0.5 = $12.5
                  expect(fixed_charge_fee.amount_cents).to eq(1250)
                end
              end
            end

            context "with volume pricing model" do
              let(:fixed_charge) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on:,
                  charge_model: "volume",
                  pay_in_advance: false,
                  units: 25,
                  properties: {
                    volume_ranges: [
                      {from_value: 0, to_value: 10, flat_amount: "0", per_unit_amount: "1"},
                      {from_value: 11, to_value: 50, flat_amount: "5", per_unit_amount: "0.8"},
                      {from_value: 51, to_value: nil, flat_amount: "10", per_unit_amount: "0.5"}
                    ]
                  }
                )
              end

              before do
                fixed_charge

                # Volume pricing requires pay_in_arrears, so we need to simulate subsequent invoice
                # Create 2 invoice_subscriptions to mark as subsequent (not starting)
                create(
                  :invoice_subscription,
                  subscription:,
                  invoicing_reason: :subscription_starting,
                  from_datetime: subscription.started_at,
                  to_datetime: subscription.started_at + 1.month,
                  created_at: 1.month.ago
                )

                create(
                  :invoice_subscription,
                  subscription:,
                  invoicing_reason: :subscription_periodic,
                  from_datetime: subscription.started_at + 1.month,
                  to_datetime: subscription.started_at + 2.months,
                  created_at: 15.days.ago
                )

                event_timestamp = subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription:,
                  fixed_charge:,
                  units: fixed_charge.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )
              end

              it "calculates volume pricing correctly" do
                travel_to(timestamp) do
                  result = preview_service.call

                  expect(result).to be_success

                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  fixed_charge_fee = fixed_charge_fees.first
                  # 25 units falls in second tier: $5 flat + (25 * $0.8) = $25
                  expect(fixed_charge_fee.amount_cents).to eq(2500)
                end
              end
            end
          end

          context "with minimum commitment" do
            let(:timestamp) { Time.zone.parse("1 Jan 2024") }
            let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: false, amount_cents: 0) }
            let!(:commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_00) }

            it "includes a non-persisted commitment fee when preview fees are below the minimum" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success

                commitment_fees = result.invoice.fees.select { |f| f.fee_type == "commitment" }
                expect(commitment_fees.size).to eq(1)

                commitment_fee = commitment_fees.first
                expect(commitment_fee).not_to be_persisted
                expect(commitment_fee.invoiceable_type).to eq("Commitment")
                expect(commitment_fee.invoiceable_id).to eq(commitment.id)
                expect(commitment_fee.amount_cents).to eq(commitment.amount_cents)
                expect(commitment_fee.subscription).to eq(subscription)
              end
            end
          end

          context "when preview premium integration does not exist" do
            before { organization.update!(premium_integrations: ["netsuite"]) }

            it "returns an error" do
              result = preview_service.call

              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
            end
          end

          context "when subscription is terminated" do
            let(:subscription) do
              create(
                :subscription,
                customer:,
                plan:,
                billing_time:,
                subscription_at: timestamp,
                started_at: timestamp,
                created_at: timestamp
              )
            end
            let(:billable_metric) do
              create(:billable_metric, aggregation_type: "count_agg")
            end
            let(:charge) do
              create(
                :standard_charge,
                plan:,
                billable_metric:,
                properties: {amount: "12.66"}
              )
            end
            let(:events) do
              create_pair(
                :event,
                organization:,
                subscription:,
                customer:,
                code: billable_metric.code,
                timestamp: timestamp + 5.hours
              )
            end

            before do
              subscription.assign_attributes(
                status: "terminated",
                terminated_at: timestamp + 15.hours
              )

              events
              charge
              Rails.cache.clear
            end

            it "creates preview invoice for 1 day", transaction: false do
              # One days should be billed, Mar 30 only

              travel_to(subscription.terminated_at) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.subscriptions.first).to eq(subscription)
                expect(result.invoice.fees.length).to eq(2)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-03-30")
                expect(result.invoice.fees_amount_cents).to eq(2535) # 3.23 + 1266 x 2 = 2535
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(2535)
                expect(result.invoice.taxes_amount_cents).to eq(1268) # 1268
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(3803) # 3803
                expect(result.invoice.total_amount_cents).to eq(3803) # 3803
              end
            end

            context "with fixed charges" do
              let(:add_on_advance) { create(:add_on, organization:) }
              let(:add_on_arrears) { create(:add_on, organization:) }
              let(:fixed_charge_advance) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on: add_on_advance,
                  charge_model: "standard",
                  pay_in_advance: true,
                  units: 1,
                  properties: {amount: "10"}
                )
              end
              let(:fixed_charge_arrears) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on: add_on_arrears,
                  charge_model: "standard",
                  pay_in_advance: false,
                  units: 1,
                  properties: {amount: "5"}
                )
              end

              before do
                fixed_charge_advance
                fixed_charge_arrears

                event_timestamp = subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription:,
                  fixed_charge: fixed_charge_arrears,
                  units: fixed_charge_arrears.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )
              end

              it "excludes pay_in_advance and includes pay_in_arrears fixed charges", transaction: false do
                travel_to(subscription.terminated_at) do
                  result = preview_service.call

                  expect(result).to be_success

                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  expect(fixed_charge_fees.size).to eq(1)

                  fixed_charge_fee = fixed_charge_fees.first
                  expect(fixed_charge_fee.fixed_charge).to eq(fixed_charge_arrears)
                  expect(fixed_charge_fee.amount_cents).to eq(500) # $5 * 1 unit

                  # Should NOT include pay_in_advance fixed charge
                  fixed_charge_ids = fixed_charge_fees.map(&:fixed_charge_id)
                  expect(fixed_charge_ids).not_to include(fixed_charge_advance.id)
                end
              end
            end
          end

          context "when subscription is upgraded" do
            let(:timestamp) { Time.zone.parse("29 Mar 2024") }
            let(:plan_new) { create(:plan, organization:, interval: "monthly", amount_cents: 200) }
            let(:subscriptions) { [terminated_subscription, upgrade_subscription] }
            let(:terminated_subscription) do
              create(
                :subscription,
                customer:,
                plan:,
                billing_time:,
                subscription_at: timestamp,
                started_at: timestamp,
                created_at: timestamp
              )
            end
            let(:upgrade_subscription) do
              build(
                :subscription,
                customer:,
                plan: plan_new,
                billing_time:,
                status: "active",
                subscription_at: timestamp + 15.hours,
                started_at: timestamp + 15.hours,
                created_at: timestamp + 15.hours
              )
            end
            let(:billable_metric) do
              create(:billable_metric, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
            end
            let(:charge) do
              create(
                :standard_charge,
                plan:,
                billable_metric:,
                pay_in_advance: false,
                prorated: true,
                properties: {amount: "1"}
              )
            end
            let(:events) do
              create_pair(
                :event,
                organization:,
                subscription: terminated_subscription,
                customer:,
                code: billable_metric.code,
                timestamp: timestamp + 5.hours,
                properties: {amount: "5"}
              )
            end

            before do
              BillSubscriptionJob.perform_now(
                [terminated_subscription],
                timestamp.to_i,
                invoicing_reason: :subscription_starting
              )

              # Create a second invoice_subscription to mark terminated_subscription as subsequent (not starting)
              create(
                :invoice_subscription,
                subscription: terminated_subscription,
                invoicing_reason: :subscription_periodic,
                from_datetime: timestamp + 1.day,
                to_datetime: timestamp + 15.hours,
                created_at: timestamp + 1.day
              )

              terminated_subscription.assign_attributes(
                status: "terminated",
                terminated_at: timestamp + 15.hours
              )

              events
              charge
              Rails.cache.clear
            end

            it "creates preview invoice for 1 day", transaction: false do
              # One days should be billed, Mar 30 only

              travel_to(terminated_subscription.terminated_at) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.subscriptions.size).to eq(2)
                expect(result.invoice.fees.length).to eq(2)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-03-29")
                expect(result.invoice.fees_amount_cents).to eq(35) # 3.23 + 32.26 (charge) = 35
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(35)
                expect(result.invoice.taxes_amount_cents).to eq(18)
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(53)
                expect(result.invoice.total_amount_cents).to eq(53)
              end
            end

            context "with fixed charges on both plans" do
              let(:add_on_old) { create(:add_on, organization:) }
              let(:add_on_new) { create(:add_on, organization:) }
              let(:fixed_charge_old_plan) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on: add_on_old,
                  charge_model: "standard",
                  pay_in_advance: false,
                  units: 1,
                  properties: {amount: "5"}
                )
              end
              let(:fixed_charge_new_plan) do
                create(
                  :fixed_charge,
                  plan: plan_new,
                  add_on: add_on_new,
                  charge_model: "standard",
                  pay_in_advance: true,
                  units: 1,
                  properties: {amount: "8"}
                )
              end

              before do
                fixed_charge_old_plan
                fixed_charge_new_plan

                old_event_timestamp = terminated_subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription: terminated_subscription,
                  fixed_charge: fixed_charge_old_plan,
                  units: fixed_charge_old_plan.units,
                  timestamp: old_event_timestamp,
                  created_at: old_event_timestamp
                )

                new_event_timestamp = upgrade_subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription: upgrade_subscription,
                  fixed_charge: fixed_charge_new_plan,
                  units: fixed_charge_new_plan.units,
                  timestamp: new_event_timestamp,
                  created_at: new_event_timestamp
                )
              end

              it "includes fixed charges from both old and new plans", transaction: false do
                travel_to(terminated_subscription.terminated_at) do
                  result = preview_service.call

                  expect(result).to be_success
                  expect(result.invoice.subscriptions.size).to eq(2)

                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  expect(fixed_charge_fees.size).to eq(2)

                  # Old plan pay_in_arrears fixed charge should be included
                  old_plan_fixed_fees = fixed_charge_fees.select { |f| f.subscription == terminated_subscription }
                  expect(old_plan_fixed_fees.size).to eq(1)
                  expect(old_plan_fixed_fees.first.amount_cents).to eq(500) # $5

                  # New plan pay_in_advance fixed charge should be included
                  new_plan_fixed_fees = fixed_charge_fees.select { |f| f.subscription == upgrade_subscription }
                  expect(new_plan_fixed_fees.size).to eq(1)
                  expect(new_plan_fixed_fees.first.amount_cents).to eq(800) # $8
                end
              end
            end
          end

          context "when subscription is downgraded" do
            let(:timestamp) { Time.zone.parse("29 Mar 2024") }
            let(:rotate_timestamp) { Time.zone.parse("1 Apr 2024 01:00") }
            let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: true) }
            let(:plan_new) { create(:plan, organization:, interval: "monthly", amount_cents: 50, pay_in_advance: true) }
            let(:subscriptions) { [terminated_subscription, downgraded_subscription] }

            let(:terminated_subscription) do
              create(
                :subscription,
                customer:,
                plan:,
                billing_time:,
                subscription_at: timestamp,
                started_at: timestamp,
                created_at: timestamp
              )
            end

            let(:downgraded_subscription) do
              build(
                :subscription,
                customer:,
                plan: plan_new,
                billing_time:,
                status: "active",
                subscription_at: rotate_timestamp,
                started_at: rotate_timestamp,
                created_at: rotate_timestamp
              )
            end

            let(:billable_metric) do
              create(:billable_metric, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
            end

            let(:charge) do
              create(
                :standard_charge,
                plan:,
                billable_metric:,
                pay_in_advance: false,
                prorated: true,
                properties: {amount: "1"}
              )
            end

            let(:events) do
              create_pair(
                :event,
                organization:,
                subscription: terminated_subscription,
                customer:,
                code: billable_metric.code,
                timestamp: timestamp + 5.hours,
                properties: {amount: "5"}
              )
            end

            before do
              BillSubscriptionJob.perform_now(
                [terminated_subscription],
                timestamp.to_i,
                invoicing_reason: :subscription_starting
              )

              terminated_subscription.assign_attributes(
                status: "terminated",
                terminated_at: rotate_timestamp,
                next_subscriptions: [downgraded_subscription]
              )

              events
              charge
              Rails.cache.clear
            end

            it "creates preview invoice", transaction: false do
              # only charges from March (3 days), full April billed by new plan

              travel_to(Time.zone.parse("30 Mar 2024 05:00")) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.subscriptions.size).to eq(2)
                expect(result.invoice.fees.length).to eq(2)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
                expect(result.invoice.fees_amount_cents).to eq(147) # 97 (charges) + 50 (new plan) = 147
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(147)
                expect(result.invoice.taxes_amount_cents).to eq(74) # 49 (charges) + 25 (new plan) = 90
                expect(result.invoice.credit_notes_amount_cents).to eq(0)
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(221)
                expect(result.invoice.total_amount_cents).to eq(221)
              end
            end

            context "with fixed charges on both plans" do
              let(:add_on_old) { create(:add_on, organization:) }
              let(:add_on_new) { create(:add_on, organization:) }
              let(:fixed_charge_old_plan) do
                create(
                  :fixed_charge,
                  plan:,
                  add_on: add_on_old,
                  charge_model: "standard",
                  pay_in_advance: true,
                  units: 1,
                  properties: {amount: "10"}
                )
              end
              let(:fixed_charge_new_plan) do
                create(
                  :fixed_charge,
                  plan: plan_new,
                  add_on: add_on_new,
                  charge_model: "standard",
                  pay_in_advance: true,
                  units: 1,
                  properties: {amount: "3"}
                )
              end

              before do
                fixed_charge_old_plan
                fixed_charge_new_plan

                event_timestamp = downgraded_subscription.started_at + 1.second
                create(
                  :fixed_charge_event,
                  organization:,
                  subscription: downgraded_subscription,
                  fixed_charge: fixed_charge_new_plan,
                  units: fixed_charge_new_plan.units,
                  timestamp: event_timestamp,
                  created_at: event_timestamp
                )
              end

              it "includes fixed charges from new plan only", transaction: false do
                # Old plan pay_in_advance should NOT be included (terminated)
                # New plan pay_in_advance should be included

                travel_to(Time.zone.parse("30 Mar 2024 05:00")) do
                  result = preview_service.call

                  expect(result).to be_success
                  expect(result.invoice.subscriptions.size).to eq(2)

                  # Should only have fixed charge from new plan (pay_in_advance not charged on terminated subscription)
                  fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                  expect(fixed_charge_fees.size).to eq(1)

                  # New plan pay_in_advance fixed charge should be included
                  new_plan_fixed_fee = fixed_charge_fees.first
                  expect(new_plan_fixed_fee.subscription).to eq(downgraded_subscription)
                  expect(new_plan_fixed_fee.amount_cents).to eq(300) # $3
                end
              end
            end
          end
        end

        context "with in advance billing in the future" do
          let(:organization) { create(:organization) }
          let(:billing_entity) { create(:billing_entity, organization:, invoice_grace_period: 2) }
          let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: true) }
          let(:subscription) do
            build(
              :subscription,
              customer:,
              plan:,
              billing_time:,
              subscription_at: timestamp + 1.day,
              started_at: timestamp + 1.day,
              created_at: timestamp + 1.day
            )
          end

          it "creates preview invoice for 1 day" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.first).to eq(subscription)
              expect(result.invoice.fees.length).to eq(1)
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-04-02")
              expect(result.invoice.fees_amount_cents).to eq(3)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(3)
              expect(result.invoice.taxes_amount_cents).to eq(2)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(5)
              expect(result.invoice.total_amount_cents).to eq(5)
            end
          end
        end

        context "with in advance billing with persisted subscription" do
          let(:customer) { create(:customer, organization:, billing_entity:) }
          let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: true) }
          let(:subscription) do
            create(
              :subscription,
              customer:,
              plan:,
              billing_time:,
              subscription_at: timestamp - 1.day,
              started_at: timestamp - 1.day,
              created_at: timestamp - 1.day
            )
          end

          before { organization.update!(premium_integrations: ["preview"]) }

          it "creates preview invoice for next invoice" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.first).to eq(subscription)
              expect(result.invoice.fees.length).to eq(1)
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
              expect(result.invoice.fees_amount_cents).to eq(100)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(100)
              expect(result.invoice.taxes_amount_cents).to eq(50)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(150)
              expect(result.invoice.total_amount_cents).to eq(150)
            end
          end

          context "with terminated subscription" do
            let(:subscription) do
              create(
                :subscription,
                customer:,
                plan:,
                billing_time:,
                status: "terminated",
                terminated_at: timestamp,
                subscription_at: timestamp - 1.day,
                started_at: timestamp - 1.day,
                created_at: timestamp - 1.day
              )
            end

            it "creates preview invoice without subscription fee since it has already been paid" do
              travel_to(subscription.terminated_at) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.subscriptions.first).to eq(subscription)
                expect(result.invoice.fees.length).to eq(0)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-03-30")
                expect(result.invoice.fees_amount_cents).to eq(0)
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(0)
                expect(result.invoice.taxes_amount_cents).to eq(0)
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(0)
                expect(result.invoice.total_amount_cents).to eq(0)
              end
            end
          end

          context "with upgraded subscription" do
            let(:timestamp) { Time.zone.parse("29 Mar 2024") }
            let(:plan_new) { create(:plan, charges:, organization:, interval: "monthly", amount_cents: 200, pay_in_advance: true) }
            let(:subscriptions) { [terminated_subscription, upgrade_subscription] }
            let(:terminated_subscription) do
              create(
                :subscription,
                customer:,
                plan:,
                billing_time:,
                subscription_at: timestamp - 1.day,
                started_at: timestamp - 1.day,
                created_at: timestamp - 1.day
              )
            end
            let(:upgrade_subscription) do
              build(
                :subscription,
                customer:,
                plan: plan_new,
                billing_time:,
                status: "active",
                subscription_at: timestamp,
                started_at: timestamp,
                created_at: timestamp
              )
            end

            let(:charges) { [build(:standard_charge)] }

            before do
              BillSubscriptionJob.perform_now(
                [terminated_subscription],
                timestamp.to_i,
                invoicing_reason: :subscription_starting
              )

              terminated_subscription.assign_attributes(
                status: "terminated",
                terminated_at: timestamp
              )
            end

            it "creates preview invoice for upgrade case" do
              travel_to(terminated_subscription.terminated_at) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.subscriptions.size).to eq(2)
                expect(result.invoice.credits.length).to eq(1)
                # precise_amount 6.45161 + precise_taxes_amount_cents 3.225805 = 9.677415 ajusted(9)
                expect(result.invoice.credits.first.amount_cents).to eq(9)
                expect(result.invoice.fees.length).to eq(1)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-03-29")
                expect(result.invoice.fees_amount_cents).to eq(19) # 3 x 200 / 31
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(19)
                expect(result.invoice.taxes_amount_cents).to eq(10)
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(29)
                expect(result.invoice.total_amount_cents).to eq(20)
              end
            end
          end

          context "when preview premium integration does not exist" do
            before { organization.update!(premium_integrations: ["netsuite"]) }

            it "returns an error" do
              result = preview_service.call

              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
            end
          end
        end

        context "with applied coupons" do
          let(:applied_coupon) do
            build(
              :applied_coupon,
              customer: subscription.customer,
              amount_cents: 2,
              amount_currency: plan.amount_currency
            )
          end

          it "creates preview invoice for 2 days with applied coupons" do
            travel_to(timestamp) do
              result = described_class.new(customer:, subscriptions: [subscription], applied_coupons: [applied_coupon]).call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.first).to eq(subscription)
              expect(result.invoice.fees.length).to eq(1)
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
              expect(result.invoice.fees_amount_cents).to eq(6)
              expect(result.invoice.coupons_amount_cents).to eq(2)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(4)
              expect(result.invoice.taxes_amount_cents).to eq(2)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(6)
              expect(result.invoice.total_amount_cents).to eq(6)
              expect(result.invoice.credits.length).to eq(1)
            end
          end
        end

        context "with credit note credits" do
          let(:credit_note) do
            create(
              :credit_note,
              customer:,
              total_amount_cents: 2,
              total_amount_currency: plan.amount_currency,
              balance_amount_cents: 2,
              balance_amount_currency: plan.amount_currency,
              credit_amount_cents: 2,
              credit_amount_currency: plan.amount_currency
            )
          end

          before { credit_note }

          it "creates preview invoice for 2 days with credits included" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.first).to eq(subscription)
              expect(result.invoice.fees.length).to eq(1)
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
              expect(result.invoice.fees_amount_cents).to eq(6)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(6)
              expect(result.invoice.taxes_amount_cents).to eq(3)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(9)
              expect(result.invoice.credit_notes_amount_cents).to eq(2)
              expect(result.invoice.total_amount_cents).to eq(7)
            end
          end
        end

        context "with wallet credits" do
          let(:wallet) { build(:wallet, customer:, balance: "0.03", credits_balance: "0.03") }

          before { wallet }

          context "with customer that is not persisted" do
            it "does not apply credits" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.total_amount_cents).to eq(9)
                expect(result.invoice.prepaid_credit_amount_cents).to eq(0)
              end
            end
          end

          context "with customer that is persisted" do
            let(:customer) { create(:customer, organization:, billing_entity:) }
            let(:wallet) { create(:wallet, customer:, balance: "0.03", credits_balance: "0.03") }

            it "applies credits" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.subscriptions.first).to eq(subscription)
                expect(result.invoice.fees.length).to eq(1)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
                expect(result.invoice.fees_amount_cents).to eq(6)
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(6)
                expect(result.invoice.taxes_amount_cents).to eq(3)
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(9)
                expect(result.invoice.prepaid_credit_amount_cents).to eq(3)
                expect(result.invoice.total_amount_cents).to eq(6)
              end
            end
          end
        end

        context "with provider taxes" do
          let(:integration) { create(:anrok_integration, organization:) }
          let(:integration_customer) { build(:anrok_customer, integration:, customer:) }
          let(:endpoint) { "https://api.nango.dev/v1/anrok/draft_invoices" }
          let(:integration_collection_mapping) do
            create(
              :netsuite_collection_mapping,
              integration:,
              mapping_type: :fallback_item,
              settings: {external_id: "1", external_account_code: "11", external_name: ""}
            )
          end

          before do
            integration_collection_mapping
            customer.integration_customers = [integration_customer]
          end

          context "when there is no error" do
            before do
              stub_request(:post, endpoint).to_return do |request|
                response = JSON.parse(File.read(
                  Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
                ))

                # setting item_id based on the test example
                key = JSON.parse(request.body).first["fees"].last["item_key"]
                response["succeededInvoices"].first["fees"].last["item_key"] = key

                {body: response.to_json}
              end
            end

            it "creates preview invoice for 2 days" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.organization).to eq(organization)
                expect(result.invoice.billing_entity).to eq(customer.billing_entity)
                expect(result.invoice.subscriptions.first).to eq(subscription)
                expect(result.invoice.fees.length).to eq(1)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
                expect(result.invoice.fees_amount_cents).to eq(6)
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(6)
                expect(result.invoice.taxes_amount_cents).to eq(1) # 6 x 0.1
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(7)
                expect(result.invoice.total_amount_cents).to eq(7)
              end
            end
          end

          context "when there is error received from the provider" do
            before do
              stub_request(:post, endpoint).to_return do |request|
                response = File.read(
                  Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
                )
                {body: response}
              end
            end

            it "uses zero taxes" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.subscriptions.first).to eq(subscription)
                expect(result.invoice.fees.length).to eq(1)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
                expect(result.invoice.fees_amount_cents).to eq(6)
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(6)
                expect(result.invoice.taxes_amount_cents).to eq(0)
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(6)
                expect(result.invoice.total_amount_cents).to eq(6)
              end
            end
          end

          context "when there is Net::OpenTimeout error" do
            before do
              allow(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).to receive(:new)
                .and_raise(Integrations::Aggregator::TimeoutError)
            end

            it "uses zero taxes" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.subscriptions.first).to eq(subscription)
                expect(result.invoice.fees.length).to eq(1)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
                expect(result.invoice.fees_amount_cents).to eq(6)
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(6)
                expect(result.invoice.taxes_amount_cents).to eq(0)
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(6)
                expect(result.invoice.total_amount_cents).to eq(6)
              end
            end
          end
        end
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }

        it "creates preview invoice for full month" do
          travel_to(timestamp) do
            result = preview_service.call

            expect(result).to be_success
            expect(result.invoice.organization).to eq(organization)
            expect(result.invoice.billing_entity).to eq(customer.billing_entity)
            expect(result.invoice.subscriptions.first).to eq(subscription)
            expect(result.invoice.fees.length).to eq(1)
            expect(result.invoice.invoice_type).to eq("subscription")
            expect(result.invoice.issuing_date.to_s).to eq("2024-04-30")
            expect(result.invoice.fees_amount_cents).to eq(100)
            expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(100)
            expect(result.invoice.taxes_amount_cents).to eq(50)
            expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(150)
            expect(result.invoice.total_amount_cents).to eq(150)
          end
        end

        context "with fixed charges for non-persisted subscription" do
          let(:plan) { create(:plan, organization:, interval: "monthly", amount_cents: 1000) }
          let(:add_on) { create(:add_on, organization:) }

          context "with graduated charge model" do
            let(:fixed_charge) do
              create(
                :fixed_charge,
                plan:,
                add_on:,
                charge_model: "graduated",
                pay_in_advance: true,
                units: 25,
                properties: {
                  graduated_ranges: [
                    {from_value: 0, to_value: 10, flat_amount: "0", per_unit_amount: "2"},
                    {from_value: 11, to_value: 20, flat_amount: "5", per_unit_amount: "1.5"},
                    {from_value: 21, to_value: nil, flat_amount: "10", per_unit_amount: "1"}
                  ]
                }
              )
            end

            before { fixed_charge }

            it "calculates graduated pricing using default units" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.fees.size).to eq(2) # subscription + fixed_charge

                fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                expect(fixed_charge_fees.size).to eq(1)

                fixed_charge_fee = fixed_charge_fees.first
                # Tier 1: 10 units * $2 = $20
                # Tier 2: $5 flat + (10 units * $1.5) = $20
                # Tier 3: $10 flat + (5 units * $1) = $15
                # Total: $20 + $20 + $15 = $55
                expect(fixed_charge_fee.amount_cents).to eq(5500)
                expect(fixed_charge_fee.units).to eq(25)

                # Total: subscription (1000) + fixed charge (5500) = 6500
                expect(result.invoice.fees_amount_cents).to eq(6500)
              end
            end
          end
        end

        context "with one persisted subscriptions" do
          let(:customer) { create(:customer, organization:, billing_entity:) }
          let(:subscription) do
            create(
              :subscription,
              customer:,
              plan:,
              billing_time:,
              subscription_at: timestamp,
              started_at: timestamp,
              created_at: timestamp
            )
          end

          before { organization.update!(premium_integrations: ["preview"]) }

          it "creates preview invoice for full month" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.first).to eq(subscription)
              expect(result.invoice.fees.length).to eq(1)
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-04-30")
              expect(result.invoice.fees_amount_cents).to eq(100)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(100)
              expect(result.invoice.taxes_amount_cents).to eq(50)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(150)
              expect(result.invoice.total_amount_cents).to eq(150)
            end
          end

          context "with charge fees" do
            let(:billable_metric) do
              create(:billable_metric, aggregation_type: "count_agg")
            end
            let(:charge) do
              create(
                :standard_charge,
                plan:,
                billable_metric:,
                properties: {amount: "12.66"}
              )
            end
            let(:events) do
              create_list(
                :event,
                2,
                organization:,
                subscription:,
                customer:,
                code: billable_metric.code,
                timestamp: timestamp + 10.hours
              )
            end

            before do
              events if subscription
              charge
              Rails.cache.clear
            end

            it "creates preview invoice for full month", transaction: false do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.organization).to eq(organization)
                expect(result.invoice.billing_entity).to eq(customer.billing_entity)
                expect(result.invoice.subscriptions.first).to eq(subscription)
                expect(result.invoice.fees.length).to eq(2)
                expect(result.invoice.invoice_type).to eq("subscription")
                expect(result.invoice.issuing_date.to_s).to eq("2024-04-30")
                expect(result.invoice.fees_amount_cents).to eq(2632)
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(2632)
                expect(result.invoice.taxes_amount_cents).to eq(1316)
                expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(3948)
                expect(result.invoice.total_amount_cents).to eq(3948)
              end
            end
          end

          context "with fixed charges" do
            let(:add_on) { create(:add_on, organization:) }
            let(:fixed_charge) do
              create(
                :fixed_charge,
                plan:,
                add_on:,
                charge_model: "standard",
                pay_in_advance: true,
                units: 2,
                properties: {amount: "7.5"}
              )
            end

            before do
              fixed_charge

              event_timestamp = subscription.started_at + 1.second
              create(
                :fixed_charge_event,
                organization:,
                subscription:,
                fixed_charge:,
                units: fixed_charge.units,
                timestamp: event_timestamp,
                created_at: event_timestamp
              )
            end

            it "creates preview invoice with fixed charges for anniversary billing" do
              travel_to(timestamp) do
                result = preview_service.call

                expect(result).to be_success
                expect(result.invoice.fees.size).to eq(2) # subscription + fixed_charge

                fixed_charge_fees = result.invoice.fees.select { |f| f.fee_type == "fixed_charge" }
                expect(fixed_charge_fees.size).to eq(1)

                fixed_charge_fee = fixed_charge_fees.first
                expect(fixed_charge_fee.amount_cents).to eq(1500) # $7.5 * 2 units = $15

                # Total: subscription (100) + fixed charge (1500) = 1600
                expect(result.invoice.fees_amount_cents).to eq(1600)
                expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(1600)
                expect(result.invoice.taxes_amount_cents).to eq(800) # 50% tax
                expect(result.invoice.total_amount_cents).to eq(2400)
              end
            end
          end
        end

        context "with multiple persisted subscriptions" do
          let(:customer) { create(:customer, organization:, invoice_grace_period: 3, billing_entity:) }
          let(:plan1) { create(:plan, organization:, interval: "monthly") }
          let(:plan2) { create(:plan, organization:, interval: "monthly") }
          let(:subscriptions) { [subscription1, subscription2] }
          let(:subscription1) do
            create(
              :subscription,
              customer:,
              plan: plan1,
              billing_time:,
              subscription_at: timestamp,
              started_at: timestamp,
              created_at: timestamp
            )
          end
          let(:subscription2) do
            create(
              :subscription,
              customer:,
              plan: plan2,
              billing_time:,
              subscription_at: timestamp,
              started_at: timestamp,
              created_at: timestamp
            )
          end

          before { organization.update!(premium_integrations: ["preview"]) }

          it "creates preview invoice for full month" do
            travel_to(timestamp + 5.days) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.map { |s| s.id }).to match_array([subscription1.id, subscription2.id])
              expect(result.invoice.fees.length).to eq(2)
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-05-03")
              expect(result.invoice.fees_amount_cents).to eq(200)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(200)
              expect(result.invoice.taxes_amount_cents).to eq(100)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(300)
              expect(result.invoice.total_amount_cents).to eq(300)
            end
          end
        end
      end

      context "with pending subscription starting in the future" do
        let(:customer) { create(:customer, organization:, billing_entity:) }
        let(:timestamp) { Time.zone.parse("15 Mar 2024") }
        let(:future_start) { Time.zone.parse("1 Apr 2024") }
        let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
        let(:plan) { create(:plan, organization:, interval: "monthly", amount_cents: 1000, pay_in_advance: false) }
        let(:charge) do
          create(
            :standard_charge,
            plan:,
            billable_metric:,
            pay_in_advance: false,
            invoiceable: true,
            properties: {amount: "10"}
          )
        end
        let(:subscription) do
          build(
            :subscription,
            customer:,
            plan:,
            status: :active,
            subscription_at: future_start,
            started_at: future_start,
            billing_time: "calendar",
            created_at: future_start
          )
        end
        let(:subscriptions) { [subscription] }

        before do
          charge
          organization.update!(premium_integrations: ["preview"])
        end

        it "creates preview invoice for pending subscription with subscription fee only" do
          travel_to(timestamp) do
            result = preview_service.call

            expect(result).to be_success
            expect(result.invoice.organization).to eq(organization)
            expect(result.invoice.billing_entity).to eq(customer.billing_entity)
            expect(result.invoice.subscriptions.map(&:id)).to eq([subscription.id])
            expect(result.invoice.invoice_type).to eq("subscription")
            expect(result.invoice.issuing_date.to_s).to eq("2024-05-01")

            subscription_fee = result.invoice.fees.find { |f| f.subscription_id == subscription.id && f.charge_id.nil? }
            expect(subscription_fee).to be_present
            expect(subscription_fee.amount_cents).to eq(1000)
            expect(subscription_fee.units).to eq(1.0)

            charge_fees = result.invoice.fees.select { |f| f.charge_id.present? }
            expect(charge_fees).to be_empty

            expect(result.invoice.fees_amount_cents).to eq(1000)
            expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(1000)
            expect(result.invoice.taxes_amount_cents).to eq(500)
            expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(1500)
            expect(result.invoice.total_amount_cents).to eq(1500)
          end
        end

        context "with in advance billing in the future" do
          let(:plan) { create(:plan, organization:, interval: "monthly", amount_cents: 1000, pay_in_advance: true) }

          it "creates preview invoice for pending subscription with subscription fee only" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.map(&:id)).to eq([subscription.id])
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")

              subscription_fee = result.invoice.fees.find { |f| f.subscription_id == subscription.id && f.charge_id.nil? }
              expect(subscription_fee).to be_present
              expect(subscription_fee.amount_cents).to eq(1000)
              expect(subscription_fee.units).to eq(1.0)

              charge_fees = result.invoice.fees.select { |f| f.charge_id.present? }
              expect(charge_fees).to be_empty

              expect(result.invoice.fees_amount_cents).to eq(1000)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(1000)
              expect(result.invoice.taxes_amount_cents).to eq(500)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(1500)
              expect(result.invoice.total_amount_cents).to eq(1500)
            end
          end
        end

        context "with in advance billing in the future and anniversary interval" do
          let(:plan) { create(:plan, organization:, interval: "monthly", amount_cents: 1000, pay_in_advance: true) }
          let(:future_start) { Time.zone.parse("8 Apr 2024") }
          let(:subscription) do
            build(
              :subscription,
              customer:,
              plan:,
              status: :active,
              subscription_at: future_start,
              started_at: future_start,
              billing_time: "anniversary",
              created_at: future_start
            )
          end

          it "creates preview invoice for pending subscription with subscription fee only" do
            travel_to(timestamp) do
              result = preview_service.call

              expect(result).to be_success
              expect(result.invoice.organization).to eq(organization)
              expect(result.invoice.billing_entity).to eq(customer.billing_entity)
              expect(result.invoice.subscriptions.map(&:id)).to eq([subscription.id])
              expect(result.invoice.invoice_type).to eq("subscription")
              expect(result.invoice.issuing_date.to_s).to eq("2024-04-08")

              subscription_fee = result.invoice.fees.find { |f| f.subscription_id == subscription.id && f.charge_id.nil? }
              expect(subscription_fee).to be_present
              expect(subscription_fee.amount_cents).to eq(1000)
              expect(subscription_fee.units).to eq(1.0)

              charge_fees = result.invoice.fees.select { |f| f.charge_id.present? }
              expect(charge_fees).to be_empty

              expect(result.invoice.fees_amount_cents).to eq(1000)
              expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(1000)
              expect(result.invoice.taxes_amount_cents).to eq(500)
              expect(result.invoice.sub_total_including_taxes_amount_cents).to eq(1500)
              expect(result.invoice.total_amount_cents).to eq(1500)
            end
          end
        end
      end

      context "with issuing date preferences" do
        let(:plan) { create(:plan, organization:, pay_in_advance:, interval: "monthly") }
        let(:pay_in_advance) { false }

        before do
          organization.update!(premium_integrations: ["preview"])
        end

        context "with no preferences set on the customer level" do
          let(:billing_entity) do
            create(
              :billing_entity,
              subscription_invoice_issuing_date_anchor: "current_period_end",
              subscription_invoice_issuing_date_adjustment: "keep_anchor",
              invoice_grace_period: 3
            )
          end

          let(:customer) { create(:customer, organization:, billing_entity:) }

          it "uses billing_entity preferences" do
            travel_to(timestamp + 5.days) do
              result = preview_service.call

              expect(result.invoice.issuing_date.to_s).to eq("2024-03-31")
            end
          end
        end

        context "when invoice is not recurring" do
          let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
          let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

          before do
            subscription.terminated_at = Time.zone.now
          end

          it "ignores all issuing date preferences" do
            travel_to(timestamp + 5.days) do
              result = preview_service.call

              expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
            end
          end
        end

        context "with an existing subscription" do
          let(:customer) do
            create(
              :customer,
              billing_entity:,
              organization:,
              subscription_invoice_issuing_date_anchor:,
              subscription_invoice_issuing_date_adjustment:,
              invoice_grace_period: 3
            )
          end

          let(:subscription) do
            create(
              :subscription,
              customer:,
              plan:,
              billing_time:,
              subscription_at: timestamp,
              started_at: timestamp,
              created_at: timestamp
            )
          end

          context "with pay in advance" do
            let(:pay_in_advance) { true }

            context "with current_period_end + keep_anchor" do
              let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
              let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

              it "sets issuing_date to the current billing period end date" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-30")
                end
              end
            end

            context "with current_period_end + align_with_finalization_date" do
              let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
              let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

              it "sets issuing_date to the current billing period end date + grace period" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-05-04")
                end
              end
            end

            context "with next_period_start + keep_anchor" do
              let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
              let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

              it "sets issuing_date to the next billing period start date" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-05-01")
                end
              end
            end

            context "with next_period_start + align_with_finalization_date" do
              let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
              let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

              it "sets issuing_date to the next billing period start date + grace period" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-05-04")
                end
              end
            end
          end

          context "with arrears" do
            let(:pay_in_advance) { false }

            context "with current_period_end + keep_anchor" do
              let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
              let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

              it "sets issuing_date to the current billing period end date" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-30")
                end
              end
            end

            context "with current_period_end + align_with_finalization_date" do
              let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
              let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

              it "sets issuing_date to the current billing period end date + grace period" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-05-04")
                end
              end
            end

            context "with next_period_start + keep_anchor" do
              let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
              let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

              it "sets issuing_date to the next billing period start date" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-05-01")
                end
              end
            end

            context "with next_period_start + align_with_finalization_date" do
              let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
              let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

              it "sets issuing_date to the next billing period start date + grace period" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-05-04")
                end
              end
            end
          end
        end

        context "without an existing subscription" do
          let(:customer) do
            build(
              :customer,
              billing_entity:,
              organization:,
              subscription_invoice_issuing_date_anchor:,
              subscription_invoice_issuing_date_adjustment:,
              invoice_grace_period: 3
            )
          end

          context "with pay in advance" do
            let(:pay_in_advance) { true }

            context "with current_period_end + keep_anchor" do
              let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
              let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

              it "sets issuing_date to the current billing period end date" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-02")
                end
              end
            end

            context "with current_period_end + align_with_finalization_date" do
              let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
              let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

              it "sets issuing_date to the current billing period end date + grace period" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-02")
                end
              end
            end

            context "with next_period_start + keep_anchor" do
              let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
              let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

              it "sets issuing_date to the next billing period start date" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-02")
                end
              end
            end

            context "with next_period_start + align_with_finalization_date" do
              let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
              let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

              it "sets issuing_date to the next billing period start date + grace period" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-02")
                end
              end
            end
          end

          context "with arrears" do
            let(:pay_in_advance) { false }

            context "with current_period_end + keep_anchor" do
              let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
              let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

              it "sets issuing_date to the current billing period end date" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-03-31")
                end
              end
            end

            context "with current_period_end + align_with_finalization_date" do
              let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
              let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

              it "sets issuing_date to the current billing period end date + grace period" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-04")
                end
              end
            end

            context "with next_period_start + keep_anchor" do
              let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
              let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

              it "sets issuing_date to the next billing period start date" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-01")
                end
              end
            end

            context "with next_period_start + align_with_finalization_date" do
              let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
              let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

              it "sets issuing_date to the next billing period start date + grace period" do
                travel_to(timestamp + 5.days) do
                  result = preview_service.call

                  expect(result.invoice.issuing_date.to_s).to eq("2024-04-04")
                end
              end
            end
          end
        end
      end
    end
  end
end
