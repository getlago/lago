# frozen_string_literal: true

require "rails_helper"

describe "Charge Models - Prorated Graduated Scenarios", clickhouse: true, transaction: false do
  let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: true) }
  let(:customer) { create(:customer, organization:, name: "aaaaaabcd") }
  let(:tax) { create(:tax, organization:, rate: 0) }

  let(:plan) { create(:plan, organization:, amount_cents: 0) }
  let(:billable_metric) { create(:billable_metric, recurring: true, organization:, aggregation_type:, field_name:) }

  before { tax }

  describe "with sum_agg" do
    let(:aggregation_type) { "sum_agg" }
    let(:field_name) { "amount" }

    describe "three ranges and one overflow case" do
      it "returns the expected invoice and usage amounts" do
        Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
        WebhookEndpoint.destroy_all

        travel_to(DateTime.new(2023, 9, 1)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :graduated_charge,
          billable_metric:,
          prorated: true,
          plan:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: 5,
                per_unit_amount: "10",
                flat_amount: "100"
              },
              {
                from_value: 6,
                to_value: 15,
                per_unit_amount: "5",
                flat_amount: "50"
              },
              {
                from_value: 16,
                to_value: nil,
                per_unit_amount: "2",
                flat_amount: "0"
              }
            ]
          }
        )

        fetch_current_usage(customer:)
        expect(json[:customer_usage][:amount_cents].round(2)).to eq(0)
        expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(0)
        expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")

        travel_to(DateTime.new(2023, 9, 10)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "2"},
            value: "2",
            decimal_value: 2,
            timestamp: Time.zone.parse("2023-09-10 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(11_400)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(11_400)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("2.0")
        end

        travel_to(DateTime.new(2023, 9, 16)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "5"},
            value: "5",
            decimal_value: 5,
            timestamp: Time.zone.parse("2023-09-16 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(18_400)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(18_400)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("7.0")
        end

        travel_to(DateTime.new(2023, 9, 20)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "-6"},
            value: "-6",
            decimal_value: -6,
            timestamp: Time.zone.parse("2023-09-20 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(16_567)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(16_567)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")
        end

        travel_to(DateTime.new(2023, 9, 25)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "10"},
            value: "10",
            decimal_value: 10,
            timestamp: Time.zone.parse("2023-09-25 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(17_967)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(17_967)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("11.0")
        end

        travel_to(DateTime.new(2023, 9, 26)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "4"},
            value: "4",
            decimal_value: 4,
            timestamp: Time.zone.parse("2023-09-26 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(18_300)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(18_300)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("15.0")
        end

        travel_to(DateTime.new(2023, 9, 30)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "60"},
            value: "60",
            decimal_value: 60,
            timestamp: Time.zone.parse("2023-09-30 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(18_700)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(18_700)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("75.0")
        end

        travel_to(DateTime.new(2023, 10, 1)) do
          perform_billing

          subscription = customer.subscriptions.first
          invoice = subscription.invoices.first

          expect(invoice.total_amount_cents).to eq(18_700)
          expect(subscription.reload.invoices.count).to eq(1)
        end

        travel_to(DateTime.new(2023, 10, 5)) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(37_000)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(37_000)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("75.0")
        end

        travel_to(DateTime.new(2023, 10, 17)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {amount: "20"},
            value: "20",
            decimal_value: 20,
            timestamp: Time.zone.parse("2023-10-17 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(38_935)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(38_935)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("95.0")
        end
      end

      context "when there are old events before first invoice" do
        it "returns expected invoice and usage amounts" do
          Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
          WebhookEndpoint.destroy_all

          travel_to(DateTime.new(2023, 12, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          subscription = customer.subscriptions.active.order(created_at: :desc).first

          create(
            :graduated_charge,
            billable_metric:,
            prorated: true,
            plan:,
            properties: {
              graduated_ranges: [
                {
                  from_value: 0,
                  to_value: 5,
                  per_unit_amount: "0",
                  flat_amount: "0"
                },
                {
                  from_value: 6,
                  to_value: nil,
                  per_unit_amount: "12",
                  flat_amount: "0"
                }
              ]
            }
          )

          travel_to(DateTime.new(2023, 12, 2)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "5"},
              value: "5",
              decimal_value: 5,
              timestamp: Time.zone.parse("2023-11-17 00:00:00.000")
            )

            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "5"},
              value: "5",
              decimal_value: 5,
              timestamp: Time.zone.parse("2023-11-17 00:00:00.000")
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(6_000)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(6_000)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("10.0")
          end

          travel_to(DateTime.new(2024, 1, 1)) do
            perform_billing

            subscription = customer.subscriptions.first
            invoice = subscription.invoices.first

            expect(invoice.total_amount_cents).to eq(6_000)
            expect(subscription.reload.invoices.count).to eq(1)
          end

          travel_to(DateTime.new(2024, 1, 5)) do
            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(6_000)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(6_000)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("10.0")
          end

          travel_to(DateTime.new(2024, 1, 6)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "2"},
              value: "2",
              decimal_value: 2,
              timestamp: Time.zone.parse("2024-01-06 00:00:00.000")
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(8_013)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(8_013)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("12.0")
          end
        end
      end

      context "when there are old events before first invoice and subscription is terminated" do
        it "returns expected invoice and usage amounts" do
          Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
          WebhookEndpoint.destroy_all

          travel_to(DateTime.new(2023, 10, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          subscription = customer.subscriptions.active.order(created_at: :desc).first

          create(
            :graduated_charge,
            billable_metric:,
            prorated: true,
            plan:,
            properties: {
              graduated_ranges: [
                {
                  from_value: 0,
                  to_value: 5,
                  per_unit_amount: "0",
                  flat_amount: "0"
                },
                {
                  from_value: 6,
                  to_value: nil,
                  per_unit_amount: "10",
                  flat_amount: "0"
                }
              ]
            }
          )

          travel_to(DateTime.new(2023, 10, 5)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "4"},
              value: "4",
              decimal_value: 4,
              timestamp: Time.zone.parse("2023-10-05 00:00:00.000")
            )

            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "3"},
              value: "3",
              decimal_value: 3,
              timestamp: Time.zone.parse("2023-10-05 00:00:00.000")
            )
          end

          travel_to(DateTime.new(2023, 11, 5)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "-1"},
              value: "-1",
              decimal_value: -1,
              timestamp: Time.zone.parse("2023-11-05 00:00:00.000")
            )
          end

          travel_to(DateTime.new(2023, 12, 7)) do
            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(1_000)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(1_000)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("6.0")

            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "1"},
              value: "1",
              decimal_value: 1,
              timestamp: Time.zone.parse("2023-12-07 00:00:00.000")
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(1_806)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(1_806)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("7.0")

            Subscriptions::TerminateService.call(subscription:)
            perform_all_enqueued_jobs
            invoice = subscription.invoices.order(created_at: :desc).first

            expect(subscription.reload).to be_terminated
            expect(subscription.reload.invoices.count).to eq(1)
            expect(invoice.total_amount_cents).to eq(258)
            expect(invoice.issuing_date.iso8601).to eq("2023-12-07")
          end
        end
      end

      context "when upgrade is performed" do
        let(:plan_new) { create(:plan, organization:, amount_cents: 100) }

        it "returns expected invoice and usage amounts" do
          Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
          WebhookEndpoint.destroy_all

          travel_to(DateTime.new(2023, 9, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          create(
            :graduated_charge,
            billable_metric:,
            prorated: true,
            plan:,
            properties: {
              graduated_ranges: [
                {
                  from_value: 0,
                  to_value: 5,
                  per_unit_amount: "10",
                  flat_amount: "100"
                },
                {
                  from_value: 6,
                  to_value: 15,
                  per_unit_amount: "5",
                  flat_amount: "50"
                },
                {
                  from_value: 16,
                  to_value: nil,
                  per_unit_amount: "2",
                  flat_amount: "0"
                }
              ]
            }
          )

          travel_to(DateTime.new(2023, 9, 10)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "2"},
              value: "2",
              decimal_value: 2,
              timestamp: Time.zone.parse("2023-09-10 00:00:00.000")
            )
          end

          travel_to(DateTime.new(2023, 9, 16)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "5"},
              value: "5",
              decimal_value: 5,
              timestamp: Time.zone.parse("2023-09-16 00:00:00.000")
            )
          end

          travel_to(DateTime.new(2023, 9, 20)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "-6"},
              value: "-6",
              decimal_value: -6,
              timestamp: Time.zone.parse("2023-09-20 00:00:00.000")
            )
          end

          travel_to(DateTime.new(2023, 9, 25)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "10"},
              value: "10",
              decimal_value: 10,
              timestamp: Time.zone.parse("2023-09-25 00:00:00.000")
            )
          end

          travel_to(DateTime.new(2023, 9, 26)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "4"},
              value: "4",
              decimal_value: 4,
              timestamp: Time.zone.parse("2023-09-26 00:00:00.000")
            )
          end

          travel_to(DateTime.new(2023, 9, 30)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "60"},
              value: "60",
              decimal_value: 60,
              timestamp: Time.zone.parse("2023-09-30 00:00:00.000")
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(18_700)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(18_700)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("75.0")
          end

          travel_to(DateTime.new(2023, 10, 1)) do
            perform_billing

            subscription = customer.subscriptions.first
            invoice = subscription.invoices.first

            expect(invoice.total_amount_cents).to eq(18_700)
            expect(subscription.reload.invoices.count).to eq(1)
          end

          travel_to(DateTime.new(2023, 10, 5)) do
            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(37_000)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(37_000)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("75.0")
          end

          travel_to(DateTime.new(2023, 10, 17)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {amount: "20"},
              value: "20",
              decimal_value: 20,
              timestamp: Time.zone.parse("2023-10-17 00:00:00.000")
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(38_935)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(38_935)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("95.0")
          end

          subscription = customer.subscriptions.first

          travel_to(DateTime.new(2023, 10, 18, 5, 20)) do
            create(
              :graduated_charge,
              billable_metric:,
              prorated: true,
              plan: plan_new,
              properties: {
                graduated_ranges: [
                  {
                    from_value: 0,
                    to_value: 5,
                    per_unit_amount: "10",
                    flat_amount: "100"
                  },
                  {
                    from_value: 6,
                    to_value: 15,
                    per_unit_amount: "5",
                    flat_amount: "50"
                  },
                  {
                    from_value: 16,
                    to_value: nil,
                    per_unit_amount: "2",
                    flat_amount: "0"
                  }
                ]
              }
            )
            expect {
              create_subscription(
                {
                  external_customer_id: customer.external_id,
                  external_id: customer.external_id,
                  plan_code: plan_new.code
                }
              )
            }.to change { subscription.reload.status }.from("active").to("terminated")
              .and change { subscription.invoices.count }.from(1).to(2)

            invoice = subscription.invoices.order(created_at: :desc).first
            expect(invoice.fees.charge.count).to eq(1)

            # 30226 (17 / 31 * 75 units) + 2.58 (2 / 31 * 20 units - prorated event in termination period)
            expect(invoice.total_amount_cents).to eq(27_323)
          end

          travel_to(DateTime.new(2023, 11, 1)) do
            perform_billing

            subscription = customer.subscriptions.order(created_at: :desc).first
            invoice = subscription.invoices.order(created_at: :desc).first

            # (95 units * 14/31) -> 26_742 - charge fee
            # 100 * 14/31 -> 45 -> subscription fee
            expect(invoice.total_amount_cents).to eq(26_742 + 45)
            expect(subscription.reload.invoices.count).to eq(1)
          end

          travel_to(DateTime.new(2023, 11, 5)) do
            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(41_000)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(41_000)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("95.0")
          end
        end
      end
    end
  end

  describe "with unique_count_agg" do
    let(:aggregation_type) { "unique_count_agg" }
    let(:field_name) { "amount" }

    describe "two ranges" do
      it "returns the expected invoice and usage amounts" do
        Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
        WebhookEndpoint.destroy_all

        travel_to(DateTime.new(2023, 9, 1)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :graduated_charge,
          billable_metric:,
          prorated: true,
          plan:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: 1,
                per_unit_amount: "10",
                flat_amount: "100"
              },
              {
                from_value: 2,
                to_value: nil,
                per_unit_amount: "5",
                flat_amount: "50"
              }
            ]
          }
        )

        travel_to(DateTime.new(2025, 9, 10)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "1111", operation_type: "add"
            },
            value: "1111",
            timestamp: Time.zone.parse("2025-09-10 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(10_700)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(10_700)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")
        end

        travel_to(DateTime.new(2025, 9, 12)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "1111", operation_type: "remove"
            },
            value: "1111",
            timestamp: Time.zone.parse("2025-09-12 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(10_100)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(10_100)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
        end

        travel_to(DateTime.new(2025, 9, 14)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "1111", operation_type: "add"
            },
            value: "1111",
            timestamp: Time.zone.parse("2025-09-14 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(10_667)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(10_667)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")
        end

        travel_to(DateTime.new(2025, 9, 15)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "2222", operation_type: "add"
            },
            value: "2222",
            timestamp: Time.zone.parse("2025-09-15 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(15_933)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(15_933)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("2.0")
        end

        travel_to(DateTime.new(2025, 9, 16)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "2222", operation_type: "add"
            },
            value: "2222",
            timestamp: Time.zone.parse("2025-09-16 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(15_933)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(15_933)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("2.0")
        end

        travel_to(DateTime.new(2025, 9, 20)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "3333", operation_type: "add"
            },
            value: "3333",
            timestamp: Time.zone.parse("2025-09-20 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(16_117)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(16_117)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("3.0")
        end

        travel_to(DateTime.new(2025, 10, 1)) do
          perform_billing

          subscription = customer.subscriptions.first
          invoice = subscription.invoices.first

          expect(invoice.total_amount_cents).to eq(16_117)
          expect(subscription.reload.invoices.count).to eq(1)
        end

        travel_to(DateTime.new(2025, 10, 5)) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(17_000) # 100 + 10 + 50 + 5 + 5
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(17_000)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("3.0")
        end

        travel_to(DateTime.new(2025, 10, 17)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "4444", operation_type: "add"
            },
            value: "4444",
            timestamp: Time.zone.parse("2025-10-17 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(17_242)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(17_242)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("4.0")
        end

        travel_to(DateTime.new(2025, 11, 5)) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(17_500) # 100 + 10 + 50 + 5 + 5
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(17_500)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("4.0")
        end
      end
    end

    describe "two ranges and removal in another interval" do
      it "returns the expected invoice and usage amounts" do
        Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
        WebhookEndpoint.destroy_all

        travel_to(DateTime.new(2023, 9, 1)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :graduated_charge,
          billable_metric:,
          prorated: true,
          plan:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: 1,
                per_unit_amount: "10",
                flat_amount: "100"
              },
              {
                from_value: 2,
                to_value: nil,
                per_unit_amount: "5",
                flat_amount: "50"
              }
            ]
          }
        )

        travel_to(DateTime.new(2023, 9, 10)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "1111", operation_type: "add"
            },
            value: "1111",
            timestamp: Time.zone.parse("2023-09-10 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(10_700)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(10_700)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")
        end

        travel_to(DateTime.new(2023, 10, 1)) do
          perform_billing

          subscription = customer.subscriptions.first
          invoice = subscription.invoices.first

          expect(invoice.total_amount_cents).to eq(10_700)
          expect(subscription.reload.invoices.count).to eq(1)
        end

        travel_to(DateTime.new(2023, 10, 5)) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(11_000)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(11_000)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")
        end

        travel_to(DateTime.new(2023, 10, 17)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "1111", operation_type: "remove"
            },
            value: "1111",
            timestamp: Time.zone.parse("2023-10-17 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(10_548)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(10_548)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
        end

        travel_to(DateTime.new(2023, 10, 19, 0, 0, 0)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "2222", operation_type: "add"
            },
            value: "2222",
            timestamp: Time.zone.parse("2023-10-19 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(10_968)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(10_968)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")
        end

        travel_to(DateTime.new(2023, 11, 1)) do
          perform_billing

          subscription = customer.subscriptions.first
          invoice = subscription.invoices.order(created_at: :desc).first

          expect(invoice.total_amount_cents).to eq(10_968)
          expect(subscription.reload.invoices.count).to eq(2)
        end

        travel_to(DateTime.new(2023, 11, 5)) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(11_000)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(11_000)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")
        end
      end
    end

    context "with multiple events on the same day" do
      it "returns the expected invoice and usage amounts" do
        Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
        WebhookEndpoint.destroy_all

        travel_to(DateTime.new(2023, 9, 1)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        create(
          :graduated_charge,
          billable_metric:,
          prorated: true,
          plan:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: 5,
                per_unit_amount: "10",
                flat_amount: "100"
              },
              {
                from_value: 6,
                to_value: nil,
                per_unit_amount: "5",
                flat_amount: "50"
              }
            ]
          }
        )

        travel_to(DateTime.new(2023, 10, 10)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "1111", operation_type: "add"
            },
            value: "1111",
            timestamp: Time.zone.parse("2023-10-10 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(10_710)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(10_710)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")
        end

        travel_to(DateTime.new(2023, 10, 20)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "2222", operation_type: "add"
            },
            value: "2222",
            timestamp: Time.zone.parse("2023-10-20 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(11_097)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(11_097)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("2.0")
        end

        travel_to(DateTime.new(2023, 10, 20)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "3333", operation_type: "add"
            },
            value: "3333",
            timestamp: Time.zone.parse("2023-10-20 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(11_484)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(11_484)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("3.0")
        end

        travel_to(DateTime.new(2023, 10, 20)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "4444", operation_type: "add"
            },
            value: "4444",
            timestamp: Time.zone.parse("2023-10-20 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(11_871)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(11_871)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("4.0")
        end

        travel_to(DateTime.new(2023, 10, 20)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "5555", operation_type: "add"
            },
            value: "5555",
            timestamp: Time.zone.parse("2023-10-20 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(12_258)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(12_258)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("5.0")
        end

        travel_to(DateTime.new(2023, 10, 25)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              amount: "6666", operation_type: "add"
            },
            value: "6666",
            timestamp: Time.zone.parse("2023-10-25 00:00:00.000")
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(17_371)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(17_371)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("6.0")
        end

        travel_to(DateTime.new(2023, 11, 1)) do
          perform_billing

          subscription = customer.subscriptions.first
          invoice = subscription.invoices.first

          expect(invoice.total_amount_cents).to eq(17_371)
          expect(subscription.reload.invoices.count).to eq(1)
        end

        travel_to(DateTime.new(2023, 11, 5)) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(20_500)
          expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(20_500)
          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("6.0")
        end
      end

      context "when there are old events before first invoice and subscription is terminated" do
        it "returns expected invoice and usage amounts" do
          Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
          WebhookEndpoint.destroy_all

          travel_to(DateTime.new(2023, 10, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          subscription = customer.subscriptions.active.order(created_at: :desc).first

          create(
            :graduated_charge,
            billable_metric:,
            prorated: true,
            plan:,
            properties: {
              graduated_ranges: [
                {
                  from_value: 0,
                  to_value: 1,
                  per_unit_amount: "5",
                  flat_amount: "10"
                },
                {
                  from_value: 2,
                  to_value: nil,
                  per_unit_amount: "15",
                  flat_amount: "30"
                }
              ]
            }
          )

          travel_to(DateTime.new(2023, 10, 5)) do
            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {
                amount: "1111", operation_type: "add"
              },
              value: "1111",
              timestamp: Time.zone.parse("2023-10-05 00:00:00.000")
            )
          end

          travel_to(DateTime.new(2023, 12, 7)) do
            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(1_500)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(1_500)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("1.0")

            Clickhouse::EventsEnriched.create!(
              organization_id: organization.id,
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: customer.external_id,
              properties: {
                amount: "2222", operation_type: "add"
              },
              value: "2222",
              timestamp: Time.zone.parse("2023-12-07 00:00:00.000")
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:amount_cents].round(2)).to eq(5_710)
            expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(5_710)
            expect(json[:customer_usage][:charges_usage][0][:units]).to eq("2.0")

            Subscriptions::TerminateService.call(subscription:)
            perform_all_enqueued_jobs
            invoice = subscription.invoices.order(created_at: :desc).first

            expect(subscription.reload).to be_terminated
            expect(subscription.reload.invoices.count).to eq(1)
            expect(invoice.total_amount_cents).to eq(4_161)
            expect(invoice.issuing_date.iso8601).to eq("2023-12-07")
          end
        end
      end
    end

    context "when item is removed before billing period" do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: true) }
      let(:field_name) { "user_id" }

      let(:charge) do
        create(
          :graduated_charge,
          billable_metric:,
          prorated: true,
          plan:,
          properties: {
            graduated_ranges: [
              {from_value: 0, to_value: 1, per_unit_amount: "0", flat_amount: "0"},
              {from_value: 2, to_value: nil, per_unit_amount: "10", flat_amount: "0"}
            ]
          }
        )
      end

      before { charge }

      it "does not count removed user in tier assignment" do
        travel_to(DateTime.new(2024, 10, 1)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        travel_to(DateTime.new(2024, 10, 5)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {user_id: "73283", operation_type: "add"},
            value: "73283",
            timestamp: Time.zone.parse("2024-10-05 10:00:00.000")
          )
        end

        travel_to(DateTime.new(2024, 10, 6)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {user_id: "73290", operation_type: "add"},
            value: "73290",
            timestamp: Time.zone.parse("2024-10-06 10:00:00.000")
          )
        end

        travel_to(DateTime.new(2024, 10, 7)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {user_id: "78924", operation_type: "add"},
            value: "78924",
            timestamp: Time.zone.parse("2024-10-07 10:00:00.000")
          )
        end

        travel_to(DateTime.new(2024, 10, 25)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {user_id: "73290", operation_type: "remove"},
            value: "73290",
            timestamp: Time.zone.parse("2024-10-25 10:00:00.000")
          )
        end

        travel_to(DateTime.new(2024, 11, 1)) do
          perform_billing

          subscription = customer.subscriptions.first
          invoice = subscription.invoices.first

          expect(subscription.invoices.count).to eq(1)
          expect(invoice).to be_present
        end

        travel_to(DateTime.new(2024, 11, 15)) do
          fetch_current_usage(customer:)

          expect(json[:customer_usage][:charges_usage][0][:units]).to eq("2.0")
          expect(json[:customer_usage][:amount_cents]).to eq(1000)
        end

        travel_to(DateTime.new(2024, 12, 1)) do
          perform_billing

          subscription = customer.subscriptions.first
          invoice = subscription.invoices.order(created_at: :desc).first

          expect(invoice.total_amount_cents).to eq(1000)
        end
      end
    end

    # Customer use-case
    context "with combinations of add and remove" do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: true) }
      let(:field_name) { "user_id" }

      let(:charge) do
        create(
          :graduated_charge,
          billable_metric:,
          prorated: true,
          plan:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: 3,
                per_unit_amount: "0",
                flat_amount: "0"
              },
              {
                from_value: 4,
                to_value: nil,
                per_unit_amount: "10",
                flat_amount: "0"
              }
            ]
          }
        )
      end

      before { charge }

      it "returns expected usage" do
        travel_to(Time.zone.parse("2025-05-21 04:31:39")) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "anniversary"
            }
          )
        end

        travel_to(DateTime.new(2025, 5, 21)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              user_id: "49303", operation_type: "add"
            },
            value: "49303",
            timestamp: Time.zone.parse("2025-05-21 00:00:00.000")
          )
        end

        travel_to(DateTime.new(2025, 5, 31)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              user_id: "49067", operation_type: "add"
            },
            value: "49067",
            timestamp: Time.zone.parse("2025-05-31 00:00:00.000")
          )
        end

        travel_to(DateTime.new(2025, 7, 23)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              user_id: "62741", operation_type: "add"
            },
            value: "62741",
            timestamp: Time.zone.parse("2025-07-23 00:00:00.000")
          )
        end

        travel_to(DateTime.new(2025, 7, 24)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              user_id: "49067", operation_type: "remove"
            },
            value: "49067",
            timestamp: Time.zone.parse("2025-07-24 00:00:00.000")
          )
        end

        travel_to(DateTime.new(2025, 7, 24)) do
          Clickhouse::EventsEnriched.create!(
            organization_id: organization.id,
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: customer.external_id,
            properties: {
              user_id: "63011", operation_type: "add"
            },
            value: "63011",
            timestamp: Time.zone.parse("2025-07-24 00:00:00.000")
          )
        end

        travel_to(Time.zone.parse("2025-08-19 18:00:00")) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:amount_cents].round(2)).to eq(0)
        end
      end
    end
  end
end
