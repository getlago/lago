# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::ChargeService, :premium do
  subject(:charge_subscription_service) do
    described_class.new(
      invoice:,
      charge:,
      subscription:,
      boundaries:,
      context:,
      apply_taxes:,
      filtered_aggregations:
    )
  end

  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:context) { :finalize }
  let(:apply_taxes) { false }
  let(:filtered_aggregations) { nil }

  let(:subscription) do
    create(
      :subscription,
      organization:,
      status: :active,
      started_at: Time.zone.parse("2022-03-15"),
      customer:
    )
  end

  let(:boundaries) do
    BillingPeriodBoundaries.new(
      from_datetime: subscription.started_at.to_date.beginning_of_day,
      to_datetime: subscription.started_at.end_of_month.end_of_day,
      charges_from_datetime: subscription.started_at.beginning_of_day,
      charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
      timestamp: subscription.started_at.end_of_month.end_of_day + 1.second,
      charges_duration: (
        subscription.started_at.end_of_month.end_of_day - subscription.started_at.beginning_of_month
      ).fdiv(1.day).ceil
    )
  end

  let(:invoice) do
    create(:invoice, customer:, organization:)
  end

  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
  let(:charge) do
    create(
      :standard_charge,
      plan: subscription.plan,
      billable_metric:,
      properties: {
        amount: "20"
      }
    )
  end

  describe ".call" do
    context "without filters" do
      it "creates a fee" do
        result = charge_subscription_service.call
        expect(result).to be_success
        expect(result.fees.count).to be_zero
      end

      context "with an event" do
        let(:event) do
          create(
            :event,
            organization: subscription.organization,
            subscription:,
            code: billable_metric.code,
            timestamp: boundaries.charges_to_datetime - 2.days
          )
        end

        before { event }

        it "creates a fee" do
          result = charge_subscription_service.call
          expect(result).to be_success
          expect(result.fees.first).to have_attributes(
            id: String,
            organization_id: organization.id,
            billing_entity_id: invoice.customer.billing_entity_id,
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_cents: 2000,
            precise_amount_cents: 2000.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 1,
            unit_amount_cents: 2000,
            precise_unit_amount: 20,
            events_count: 1,
            payment_status: "pending"
          )
        end

        it "sets correct boundaries on the fee properties" do
          result = charge_subscription_service.call
          expect(result).to be_success
          expect(result.fees.first.properties).to include(
            "charges_from_datetime" => "2022-03-15T00:00:00.000Z",
            "charges_to_datetime" => "2022-03-31T23:59:59.999Z",
            "charges_duration" => 31,
            "fixed_charges_from_datetime" => nil,
            "fixed_charges_to_datetime" => nil,
            "fixed_charges_duration" => nil
          )
        end

        it "persists fee" do
          expect { charge_subscription_service.call }.to change(Fee, :count)
        end

        context "when charge uses presentation_group_keys" do
          let(:event) do
            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: billable_metric.code,
              timestamp: boundaries.charges_to_datetime - 2.days,
              properties: {region: "apac", value: 0}
            )
          end

          let(:billable_metric) do
            create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
          end

          let(:charge) do
            create(
              :standard_charge,
              plan: subscription.plan,
              billable_metric:,
              properties: {
                amount: "0",
                presentation_group_keys: [{value: "region"}]
              }
            )
          end

          let(:region) do
            create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa apac])
          end

          let(:europe_filter) do
            create(
              :charge_filter,
              charge:,
              properties: {
                amount: "0",
                presentation_group_keys: [{value: "region"}]
              }
            )
          end

          let(:usa_filter) do
            create(
              :charge_filter,
              charge:,
              properties: {
                amount: "0",
                presentation_group_keys: [{value: "region"}]
              }
            )
          end

          before do
            create(:charge_filter_value, charge_filter: europe_filter, billable_metric_filter: region, values: ["europe"])
            create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])

            create(
              :event,
              organization:,
              subscription:,
              code: billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {region: "europe", value: 10}
            )
            create(
              :event,
              organization:,
              subscription:,
              code: billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {region: "usa", value: 5}
            )
            create(
              :event,
              organization:,
              subscription:,
              code: billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {region: "apac", value: 3}
            )
          end

          it "builds presentation_breakdowns on each persisted fee" do
            expect { charge_subscription_service.call }.to change(Fee, :count).from(0).to(3)

            result = charge_subscription_service.call

            europe_fee = result.fees.find { |f| f.charge_filter_id == europe_filter.id }
            usa_fee = result.fees.find { |f| f.charge_filter_id == usa_filter.id }
            catch_all_fee = result.fees.find { |f| f.charge_filter_id.nil? }

            expect(europe_fee.presentation_breakdowns.map(&:presentation_by)).to match_array([{"region" => "europe"}])
            expect(usa_fee.presentation_breakdowns.map(&:presentation_by)).to match_array([{"region" => "usa"}])
            expect(catch_all_fee.presentation_breakdowns.map(&:presentation_by)).to match_array([{"region" => "apac"}])

            expect(europe_fee.presentation_breakdowns.map { |b| b.units.to_f }).to match_array([10.0])
            expect(usa_fee.presentation_breakdowns.map { |b| b.units.to_f }).to match_array([5.0])
            expect(catch_all_fee.presentation_breakdowns.map { |b| b.units.to_f }).to match_array([3.0])

            expect(result.fees.flat_map(&:presentation_breakdowns)).to all(have_attributes(organization_id: organization.id))
          end
        end

        context "with preview context" do
          let(:context) { :invoice_preview }

          it "does not persist fee" do
            expect { charge_subscription_service.call }.not_to change(Fee, :count)
          end
        end
      end

      context "with grouped standard charge" do
        let(:charge) do
          create(
            :standard_charge,
            plan: subscription.plan,
            billable_metric:,
            properties: {
              amount: "20",
              pricing_group_keys: ["cloud"]
            }
          )
        end

        let(:billable_metric) do
          create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
        end

        context "without events" do
          it "does not create a fee" do
            result = charge_subscription_service.call
            expect(result).to be_success
            expect(result.fees.count).to eq(0)
          end
        end

        context "with events" do
          before do
            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "aws", value: 10}
            )

            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "aws", value: 5}
            )

            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "gcp", value: 10}
            )
          end

          it "creates a fee for each group" do
            result = charge_subscription_service.call
            expect(result).to be_success
            expect(result.fees.count).to eq(2)

            fee1 = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
            expect(fee1).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 30_000,
              precise_amount_cents: 30_000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 15,
              unit_amount_cents: 2000,
              precise_unit_amount: 20,
              grouped_by: {"cloud" => "aws"}
            )

            fee2 = result.fees.find { |f| f.grouped_by["cloud"] == "gcp" }
            expect(fee2).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 20_000,
              precise_amount_cents: 20_000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 10,
              unit_amount_cents: 2000,
              precise_unit_amount: 20,
              grouped_by: {"cloud" => "gcp"}
            )
          end

          context "with adjusted fee" do
            let(:adjusted_fee) do
              create(
                :adjusted_fee,
                invoice:,
                subscription:,
                charge:,
                properties:,
                fee_type: :charge,
                adjusted_units: true,
                adjusted_amount: false,
                units: 3,
                grouped_by: {"cloud" => "aws"}
              )
            end

            let(:properties) do
              {
                charges_from_datetime: boundaries.charges_from_datetime,
                charges_to_datetime: boundaries.charges_to_datetime
              }
            end

            before do
              adjusted_fee
              invoice.draft!
            end

            it "creates a fee for each group" do
              result = charge_subscription_service.call
              expect(result).to be_success
              expect(result.fees.count).to eq(2)

              fee1 = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
              expect(fee1).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                charge_id: charge.id,
                amount_cents: 6_000,
                precise_amount_cents: 6_000.0,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 3,
                unit_amount_cents: 2000,
                precise_unit_amount: 20,
                grouped_by: {"cloud" => "aws"}
              )

              fee2 = result.fees.find { |f| f.grouped_by["cloud"] == "gcp" }
              expect(fee2).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                charge_id: charge.id,
                amount_cents: 20_000,
                precise_amount_cents: 20_000.0,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 10,
                unit_amount_cents: 2000,
                precise_unit_amount: 20,
                grouped_by: {"cloud" => "gcp"}
              )
            end
          end

          context "with recurring weighted sum aggregation" do
            let(:billable_metric) { create(:weighted_sum_billable_metric, :recurring, organization:) }

            it "creates a fee and a cached aggregation per group" do
              result = charge_subscription_service.call
              expect(result).to be_success

              expect(result.fees.count).to eq(2)
              expect(result.cached_aggregations.count).to eq(2)
            end
          end

          context "with custom aggregation" do
            let(:billable_metric) do
              create(:custom_billable_metric, :recurring, organization:)
            end

            it "creates a fee and a cached aggregation" do
              result = charge_subscription_service.call
              expect(result).to be_success

              expect(result.fees.count).to eq(2)
              expect(result.cached_aggregations.count).to eq(2)
            end
          end
        end
      end

      context "with pricing_group_keys and standard charge" do
        let(:charge) do
          create(
            :standard_charge,
            plan: subscription.plan,
            billable_metric:,
            properties: {
              amount: "20",
              pricing_group_keys: ["cloud"]
            }
          )
        end

        let(:billable_metric) do
          create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
        end

        context "with filters" do
          let(:charge) do
            create(
              :standard_charge,
              plan: subscription.plan,
              billable_metric:,
              properties: {
                amount: "20",
                pricing_group_keys: ["region", "country"]
              }
            )
          end
          let(:region) do
            create(:billable_metric_filter, billable_metric:, key: "region", values: %w[eu na])
          end
          let(:country) do
            create(:billable_metric_filter, billable_metric:, key: "country", values: %w[us ca fr de])
          end

          let(:eu_filter) do
            create(:charge_filter, charge:, properties: {amount: "30", pricing_group_keys: ["region", "country"]})
          end
          let(:eu_country_filter_value) { create(:charge_filter_value, charge_filter: eu_filter, billable_metric_filter: country, values: ["fr", "de"]) }
          let(:eu_region_filter_value) { create(:charge_filter_value, charge_filter: eu_filter, billable_metric_filter: region, values: ["eu"]) }

          let(:na_filter) do
            create(:charge_filter, charge:, properties: {amount: "40", pricing_group_keys: ["region", "country"]})
          end
          let(:na_country_filter_value) { create(:charge_filter_value, charge_filter: na_filter, billable_metric_filter: country, values: ["us", "ca"]) }
          let(:na_region_filter_value) { create(:charge_filter_value, charge_filter: na_filter, billable_metric_filter: region, values: ["na"]) }

          before do
            na_country_filter_value
            na_region_filter_value
            eu_country_filter_value
            eu_region_filter_value
            create_event("eu", "fr")
            create_event("eu", "de")
            create_event("na", "us")
            create_event("na", "ca")
            create_event("af", "ma")
            create_event("af", "ma")
            create_event("af", "dz")
          end

          def create_event(region, country)
            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {region:, country:, value: 1}
            )
          end

          it "creates a fee for each group" do
            result = charge_subscription_service.call
            expect(result).to be_success
            expect(result.fees.count).to eq(6)

            sorted_fees = result.fees.sort_by { [it.grouped_by["region"], it.grouped_by["country"]] }

            af_dz_fee = sorted_fees[0]
            expect(af_dz_fee).to have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 2000,
              precise_amount_cents: 2000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 1,
              unit_amount_cents: 2000,
              precise_unit_amount: 20,
              grouped_by: {"country" => "dz", "region" => "af"}
            )

            af_ma_fee = sorted_fees[1]
            expect(af_ma_fee).to have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 4000,
              precise_amount_cents: 4000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 2,
              unit_amount_cents: 2000,
              precise_unit_amount: 20,
              grouped_by: {"country" => "ma", "region" => "af"}
            )

            eu_de = sorted_fees[2]
            expect(eu_de).to have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 3000,
              precise_amount_cents: 3000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 1,
              unit_amount_cents: 3000,
              precise_unit_amount: 30,
              grouped_by: {"country" => "de", "region" => "eu"}
            )

            eu_fr = sorted_fees[3]
            expect(eu_fr).to have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 3000,
              precise_amount_cents: 3000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 1,
              unit_amount_cents: 3000,
              precise_unit_amount: 30,
              grouped_by: {"country" => "fr", "region" => "eu"}
            )

            na_ca_fee = sorted_fees[4]
            expect(na_ca_fee).to have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 4000,
              precise_amount_cents: 4000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 1,
              unit_amount_cents: 4000,
              precise_unit_amount: 40,
              grouped_by: {"country" => "ca", "region" => "na"}
            )

            na_us_fee = sorted_fees[5]
            expect(na_us_fee).to have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 4000,
              precise_amount_cents: 4000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 1,
              unit_amount_cents: 4000,
              precise_unit_amount: 40,
              grouped_by: {"country" => "us", "region" => "na"}
            )
          end
        end

        context "without events" do
          it "does not create a fee" do
            result = charge_subscription_service.call
            expect(result).to be_success
            expect(result.fees.count).to eq(0)
          end
        end

        context "with events" do
          before do
            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "aws", value: 10}
            )

            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "aws", value: 5}
            )

            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "gcp", value: 10}
            )
          end

          it "creates a fee for each group" do
            result = charge_subscription_service.call
            expect(result).to be_success
            expect(result.fees.count).to eq(2)

            fee1 = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
            expect(fee1).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 30_000,
              precise_amount_cents: 30_000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 15,
              unit_amount_cents: 2000,
              precise_unit_amount: 20,
              grouped_by: {"cloud" => "aws"}
            )

            fee2 = result.fees.find { |f| f.grouped_by["cloud"] == "gcp" }
            expect(fee2).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 20_000,
              precise_amount_cents: 20_000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 10,
              unit_amount_cents: 2000,
              precise_unit_amount: 20,
              grouped_by: {"cloud" => "gcp"}
            )
          end

          context "with adjusted fee" do
            let(:adjusted_fee) do
              create(
                :adjusted_fee,
                invoice:,
                subscription:,
                charge:,
                properties:,
                fee_type: :charge,
                adjusted_units: true,
                adjusted_amount: false,
                units: 3,
                grouped_by: {"cloud" => "aws"}
              )
            end

            let(:properties) do
              {
                charges_from_datetime: boundaries.charges_from_datetime,
                charges_to_datetime: boundaries.charges_to_datetime
              }
            end

            before do
              adjusted_fee
              invoice.draft!
            end

            it "creates a fee for each group" do
              result = charge_subscription_service.call
              expect(result).to be_success
              expect(result.fees.count).to eq(2)

              fee1 = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
              expect(fee1).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                charge_id: charge.id,
                amount_cents: 6_000,
                precise_amount_cents: 6_000.0,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 3,
                unit_amount_cents: 2000,
                precise_unit_amount: 20,
                grouped_by: {"cloud" => "aws"}
              )

              fee2 = result.fees.find { |f| f.grouped_by["cloud"] == "gcp" }
              expect(fee2).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                charge_id: charge.id,
                amount_cents: 20_000,
                precise_amount_cents: 20_000.0,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 10,
                unit_amount_cents: 2000,
                precise_unit_amount: 20,
                grouped_by: {"cloud" => "gcp"}
              )
            end
          end

          context "with recurring weighted sum aggregation" do
            let(:billable_metric) { create(:weighted_sum_billable_metric, :recurring, organization:) }

            it "creates a fee and a cached aggregation per group" do
              result = charge_subscription_service.call
              expect(result).to be_success

              expect(result.fees.count).to eq(2)
              expect(result.cached_aggregations.count).to eq(2)
            end
          end

          context "with custom aggregation" do
            let(:billable_metric) do
              create(:custom_billable_metric, :recurring, organization:)
            end

            it "creates a fee and a cached aggregation" do
              result = charge_subscription_service.call
              expect(result).to be_success

              expect(result.fees.count).to eq(2)
              expect(result.cached_aggregations.count).to eq(2)
            end
          end
        end

        context "with presentation_group_keys" do
          let(:charge) do
            create(
              :standard_charge,
              plan: subscription.plan,
              billable_metric:,
              properties: {
                amount: "20",
                pricing_group_keys: ["cloud"],
                presentation_group_keys: [{value: "region"}]
              }
            )
          end

          before do
            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "aws", region: "us-east-1", value: 10}
            )
            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "aws", region: "us-central-1", value: 5}
            )
            create(
              :event,
              organization: subscription.organization,
              subscription:,
              code: charge.billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {cloud: "gcp", region: "eu-west-1", value: 3}
            )
          end

          it "builds presentation_breakdowns scoped by pricing group on each persisted fee" do
            expect { charge_subscription_service.call }.to change(Fee, :count).from(0).to(2)

            result = charge_subscription_service.call

            aws_fee = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
            gcp_fee = result.fees.find { |f| f.grouped_by["cloud"] == "gcp" }

            expect(aws_fee.presentation_breakdowns.map(&:presentation_by)).to match_array([{"region" => "us-east-1"}, {"region" => "us-central-1"}])
            expect(aws_fee.presentation_breakdowns.map { |b| b.units.to_f }).to match_array([10.0, 5.0])

            expect(gcp_fee.presentation_breakdowns.map(&:presentation_by)).to match_array([{"region" => "eu-west-1"}])
            expect(gcp_fee.presentation_breakdowns.map { |b| b.units.to_f }).to match_array([3.0])

            expect(result.fees.flat_map(&:presentation_breakdowns)).to all(have_attributes(organization_id: organization.id))
          end

          context "with recurring weighted sum aggregation" do
            let(:billable_metric) { create(:weighted_sum_billable_metric, :recurring, organization:) }

            it "stores presentation_breakdowns on each cached aggregation scoped to its group" do
              result = charge_subscription_service.call
              expect(result).to be_success
              expect(result.cached_aggregations.count).to eq(2)

              aws_agg = result.cached_aggregations.find { |a| a.grouped_by["cloud"] == "aws" }
              gcp_agg = result.cached_aggregations.find { |a| a.grouped_by["cloud"] == "gcp" }

              expect(aws_agg.presentation_breakdowns.map { |b| b["groups"] }).to match_array(
                [{"region" => "us-east-1"}, {"region" => "us-central-1"}]
              )
              expect(aws_agg.presentation_breakdowns.map { |b| b["value"].to_f.round(5) }).to eq([2.58065, 5.16129])

              expect(gcp_agg.presentation_breakdowns.map { |b| b["groups"] }).to match_array(
                [{"region" => "eu-west-1"}]
              )

              expect(gcp_agg.presentation_breakdowns.map { |b| b["value"].to_f.round(5) }).to eq([1.54839])
            end
          end
        end
      end

      context "with accepts_target_wallet enabled" do
        let(:charge) do
          create(
            :standard_charge,
            plan: subscription.plan,
            billable_metric:,
            accepts_target_wallet: true,
            properties: {
              amount: "20"
            }
          )
        end

        let(:billable_metric) do
          create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
        end

        let(:event_wallet_1) do
          create(
            :event,
            organization: subscription.organization,
            subscription:,
            code: charge.billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"),
            properties: {target_wallet_code: "wallet_1", value: 10}
          )
        end

        let(:event_wallet_2) do
          create(
            :event,
            organization: subscription.organization,
            subscription:,
            code: charge.billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"),
            properties: {target_wallet_code: "wallet_2", value: 5}
          )
        end

        before do
          organization.update!(premium_integrations: ["events_targeting_wallets"])
          event_wallet_1
          event_wallet_2
        end

        it "creates a fee for each target_wallet_code" do
          result = charge_subscription_service.call
          expect(result).to be_success
          expect(result.fees.count).to eq(2)

          fee1 = result.fees.find { |f| f.grouped_by["target_wallet_code"] == "wallet_1" }
          expect(fee1).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_cents: 20_000,
            precise_amount_cents: 20_000.0,
            amount_currency: "EUR",
            units: 10,
            grouped_by: {"target_wallet_code" => "wallet_1"}
          )

          fee2 = result.fees.find { |f| f.grouped_by["target_wallet_code"] == "wallet_2" }
          expect(fee2).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_cents: 10_000,
            precise_amount_cents: 10_000.0,
            amount_currency: "EUR",
            units: 5,
            grouped_by: {"target_wallet_code" => "wallet_2"}
          )
        end
      end

      context "with graduated charge model" do
        let(:charge) do
          create(
            :graduated_charge,
            plan: subscription.plan,
            charge_model: "graduated",
            billable_metric:,
            properties: {
              graduated_ranges: [
                {
                  from_value: 0,
                  to_value: nil,
                  per_unit_amount: "0.01",
                  flat_amount: "0.01"
                }
              ]
            }
          )
        end

        before do
          create_list(
            :event,
            4,
            organization: subscription.organization,
            subscription:,
            code: charge.billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16")
          )
        end

        it "creates a fee" do
          result = charge_subscription_service.call
          expect(result).to be_success
          expect(result.fees.first).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_cents: 5,
            precise_amount_cents: 5.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 4.0,
            unit_amount_cents: 1,
            precise_unit_amount: 0.0125,
            events_count: 4
          )
        end
      end

      context "when fee already exists on the period" do
        before do
          create(:fee, charge:, subscription:, invoice:)
        end

        it "does not create a new fee" do
          expect { charge_subscription_service.call }.not_to change(Fee, :count)
        end
      end

      context "when billing an new upgraded subscription" do
        let(:previous_plan) { create(:plan, amount_cents: subscription.plan.amount_cents - 20) }
        let(:previous_subscription) do
          create(:subscription, plan: previous_plan, status: :terminated)
        end

        let(:event) do
          create(
            :event,
            organization: invoice.organization,
            subscription:,
            code: billable_metric.code,
            timestamp: Time.zone.parse("10 Apr 2022 00:01:00")
          )
        end

        let(:boundaries) do
          BillingPeriodBoundaries.new(
            from_datetime: Time.zone.parse("15 Apr 2022 00:01:00"),
            to_datetime: Time.zone.parse("30 Apr 2022 00:01:00"),
            charges_from_datetime: subscription.started_at,
            charges_to_datetime: Time.zone.parse("30 Apr 2022 00:01:00"),
            charges_duration: 30,
            timestamp: Time.zone.parse("2022-05-01T00:01:00")
          )
        end

        before do
          subscription.update!(previous_subscription:)
          event
        end

        it "creates a new fee for the complete period" do
          result = charge_subscription_service.call
          expect(result).to be_success
          expect(result.fees.first).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_cents: 2000,
            precise_amount_cents: 2_000.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 1
          )
        end
      end

      context "with all types of aggregation" do
        let(:event) do
          create(
            :event,
            code: billable_metric.code,
            organization: organization,
            external_subscription_id: subscription.external_id,
            timestamp: boundaries.charges_to_datetime - 2.days,
            properties: {"foo_bar" => 1}
          )
        end

        BillableMetric::AGGREGATION_TYPES.keys.each do |aggregation_type|
          before do
            billable_metric.update!(
              aggregation_type:,
              field_name: event.properties.keys.first,
              weighted_interval: "seconds",
              custom_aggregator: "def aggregate(event, agg, aggregation_properties); { total_units: 1, amount: 1 }; end"
            )
          end

          context "without pricing unit on the charge" do
            it "creates fees" do
              result = charge_subscription_service.call
              expect(result).to be_success
              expect(result.fees.first).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                charge_id: charge.id,
                amount_cents: 2000,
                precise_amount_cents: 2000.0,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 1,
                unit_amount_cents: 2000,
                precise_unit_amount: 20
              )
            end

            it "does not create pricing unit usage" do
              expect { charge_subscription_service.call }.not_to change(PricingUnitUsage, :count)
            end
          end

          context "with pricing unit on the charge" do
            before do
              create(
                :applied_pricing_unit,
                organization: subscription.organization,
                conversion_rate: 0.25,
                pricing_unitable: charge
              )
            end

            it "creates fees" do
              result = charge_subscription_service.call
              expect(result).to be_success
              expect(result.fees.first).to have_attributes(
                id: String,
                invoice_id: invoice.id,
                charge_id: charge.id,
                amount_cents: 500,
                precise_amount_cents: 500.0,
                taxes_precise_amount_cents: 0.0,
                amount_currency: "EUR",
                units: 1,
                unit_amount_cents: 500,
                precise_unit_amount: 5
              )
            end

            it "creates pricing unit usage" do
              result = charge_subscription_service.call
              expect(result).to be_success
              expect(result.fees.first.pricing_unit_usage)
                .to be_persisted
                .and have_attributes(
                  amount_cents: 2000,
                  precise_amount_cents: 2000.0,
                  unit_amount_cents: 2000
                )
            end
          end
        end
      end

      context "when there is adjusted fee" do
        let(:adjusted_fee) do
          create(
            :adjusted_fee,
            invoice:,
            subscription:,
            charge:,
            properties:,
            fee_type: :charge,
            adjusted_units: true,
            adjusted_amount: false,
            units: 3
          )
        end
        let(:properties) do
          {
            charges_from_datetime: boundaries.charges_from_datetime,
            charges_to_datetime: boundaries.charges_to_datetime
          }
        end

        before do
          adjusted_fee
          invoice.draft!
        end

        context "when skip_adjusted_fees is true" do
          subject(:charge_subscription_service) do
            described_class.new(
              invoice:,
              charge:,
              subscription:,
              boundaries:,
              context:,
              apply_taxes:,
              skip_adjusted_fees: true,
              filtered_aggregations:
            )
          end

          it "ignores the adjusted fee and bills the actual usage" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees).to be_empty
          end
        end

        context "with adjusted units" do
          it "creates a fee" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.first).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 6_000,
              precise_amount_cents: 6_000.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 3,
              unit_amount_cents: 2_000,
              precise_unit_amount: 20,
              events_count: 0,
              payment_status: "pending"
            )
          end

          context "when there is true-up fee" do
            before { charge.update!(min_amount_cents: 20_000) }

            it "creates two fees" do
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.count).to eq(2)
              expect(result.fees.pluck(:amount_cents)).to contain_exactly(6_000, 4_968)
              expect(result.fees.pluck(:precise_amount_cents)).to contain_exactly(6_000.0, 4_967.74193548387)
              expect(result.fees.pluck(:taxes_precise_amount_cents)).to contain_exactly(0.0, 0.0)
              expect(result.fees.pluck(:unit_amount_cents)).to contain_exactly(2_000, 4_968)
              expect(result.fees.pluck(:precise_unit_amount)).to contain_exactly(20, 49.6774193548387)
            end
          end

          context "with standard charge, all types of aggregation and presence of filters" do
            let(:region) do
              create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa])
            end

            let(:country) do
              create(:billable_metric_filter, billable_metric:, key: "country", values: ["france", "germany", "united kingdom"])
            end

            let(:charge) { create(:standard_charge, plan: subscription.plan, billable_metric:, properties: {amount: "10"}) }

            let(:europe_filter) { create_filter(amount: "20", values: {region => ["europe"]}) }
            let(:usa_filter) { create_filter(amount: "30", values: {region => ["usa"]}) }
            let(:france_filter) { create_filter(amount: "40.12345", values: {region => ["europe"], country => ["france"]}) }
            let(:all_values_filter) do
              all_values = [ChargeFilterValue::ALL_FILTER_VALUES]
              create_filter(amount: "50", values: {region => all_values, country => all_values})
            end

            let(:adjusted_fee) do
              create(
                :adjusted_fee,
                invoice:,
                subscription:,
                charge:,
                charge_filter: usa_filter,
                properties:,
                fee_type: :charge,
                adjusted_units: true,
                adjusted_amount: false,
                units: 3
              )
            end

            before do
              region
              country

              europe_filter
              usa_filter
              france_filter
              all_values_filter

              # usa filter events
              create_event(properties: {region: "usa", foo_bar: 12})

              # europe filter events
              create_event(properties: {region: "europe", foo_bar: 10})
              create_event(properties: {region: "europe", foo_bar: 2})
              create_event(properties: {region: "europe", country: "italy", foo_bar: 3})

              # france filter events
              create_event(properties: {region: "europe", country: "france", foo_bar: 5})

              # All values filter events
              create_event(properties: {region: "europe", country: "united kingdom", foo_bar: 5})
              create_event(properties: {region: "europe", country: "germany", foo_bar: 5})

              # No filter events
              create_event(properties: {region: "asia", country: "japan", foo_bar: 3})
              create_event(properties: {foo_bar: 2})
            end

            def create_event(properties:)
              organization = subscription.organization
              code = charge.billable_metric.code
              create(:event, organization:, subscription:, code:, timestamp: Time.zone.parse("2022-03-16"), properties:)
            end

            def create_filter(amount:, values:)
              filter = create(:charge_filter, charge:, properties: {amount:})
              values.each do |billable_metric_filter, values|
                create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values:)
              end
              filter
            end

            it "creates expected fees for sum_agg aggregation type" do
              billable_metric.update!(aggregation_type: :sum_agg, field_name: "foo_bar")
              result = charge_subscription_service.call
              expect(result).to be_success
              created_fees = result.fees

              expect(created_fees.count).to eq(5)
              expect(created_fees).to all(
                have_attributes(
                  invoice_id: invoice.id,
                  charge_id: charge.id,
                  amount_currency: "EUR"
                )
              )

              usa_fee = created_fees.find { |f| f.charge_filter == usa_filter }
              expect(usa_fee).to have_attributes(
                charge_filter: usa_filter,
                amount_cents: 9_000,
                precise_amount_cents: 9_000.0,
                taxes_precise_amount_cents: 0.0,
                units: 3,
                unit_amount_cents: 3000,
                precise_unit_amount: 30
              )

              europe_fee = created_fees.find { |f| f.charge_filter == europe_filter }
              expect(europe_fee).to have_attributes(
                charge_filter: europe_filter,
                amount_cents: 30_000,
                precise_amount_cents: 30_000.0,
                taxes_precise_amount_cents: 0.0,
                units: 15,
                unit_amount_cents: 2000,
                precise_unit_amount: 20
              )

              france_fee = created_fees.find { |f| f.charge_filter == france_filter }
              expect(france_fee).to have_attributes(
                charge_filter: france_filter,
                amount_cents: 20062,
                precise_amount_cents: 20061.725,
                taxes_precise_amount_cents: 0.0,
                units: 5,
                unit_amount_cents: 4012,
                precise_unit_amount: 40.12345
              )

              all_filter_fee = created_fees.find { |f| f.charge_filter == all_values_filter }
              expect(all_filter_fee).to have_attributes(
                charge_filter: all_values_filter,
                amount_cents: 50000,
                precise_amount_cents: 50000.0,
                taxes_precise_amount_cents: 0.0,
                units: 10,
                unit_amount_cents: 5000,
                precise_unit_amount: 50.0
              )

              no_filter_fee = created_fees.find { |f| f.charge_filter.blank? }
              expect(no_filter_fee).to have_attributes(
                charge_filter: nil,
                amount_cents: 5000,
                precise_amount_cents: 5000.0,
                taxes_precise_amount_cents: 0.0,
                units: 5,
                unit_amount_cents: 1000,
                precise_unit_amount: 10.0
              )
            end
          end
        end

        context "with adjusted amount" do
          let(:adjusted_fee) do
            create(
              :adjusted_fee,
              invoice:,
              subscription:,
              charge:,
              properties:,
              fee_type: :charge,
              adjusted_units: false,
              adjusted_amount: true,
              units: 1000,
              unit_amount_cents: 0,
              unit_precise_amount_cents: 0.1
            )
          end

          it "creates a fee" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.first).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 100,
              precise_amount_cents: 100.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 1000,
              unit_amount_cents: 0,
              precise_unit_amount: 0.001,
              events_count: 0,
              payment_status: "pending"
            )
          end
        end

        context "with adjusted display name" do
          let(:adjusted_fee) do
            create(
              :adjusted_fee,
              invoice:,
              subscription:,
              charge:,
              properties:,
              fee_type: :charge,
              adjusted_units: false,
              adjusted_amount: false,
              invoice_display_name: "test123",
              units: 3
            )
          end

          it "creates a fee" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.first).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 0,
              precise_amount_cents: 0.0,
              taxes_precise_amount_cents: 0.0,
              amount_currency: "EUR",
              units: 0,
              unit_amount_cents: 0,
              precise_unit_amount: 0,
              events_count: 0,
              payment_status: "pending",
              invoice_display_name: "test123"
            )
          end
        end

        context "with invoice NOT in draft status" do
          before { invoice.finalized! }

          it "creates a fee without using adjusted fee attributes" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.first).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_cents: 0,
              amount_currency: "EUR",
              units: 0,
              unit_amount_cents: 0,
              precise_unit_amount: 0,
              events_count: 0,
              payment_status: "pending"
            )
          end
        end
      end

      context "with true-up fee" do
        it "creates two fees" do
          travel_to(Time.zone.parse("2023-04-01")) do
            charge.update!(min_amount_cents: 1000)
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.count).to eq(2)
            expect(result.fees.pluck(:amount_cents)).to contain_exactly(0, 548) # 548 is 1000 prorated for 17 days.
            expect(result.fees.pluck(:precise_amount_cents)).to contain_exactly(0.0, 548.3870967741935) # 548 is 1000 prorated for 17 days.
            expect(result.fees.pluck(:taxes_precise_amount_cents)).to contain_exactly(0.0, 0.0) # 548 is 1000 prorated for 17 days.
            expect(result.fees.pluck(:unit_amount_cents)).to contain_exactly(0, 548)
            expect(result.fees.pluck(:precise_unit_amount)).to contain_exactly(0, 5.483870967741935)
          end
        end

        context "with charge using pricing units" do
          before do
            create(
              :applied_pricing_unit,
              organization: charge.organization,
              conversion_rate: 1,
              pricing_unitable: charge
            )
          end

          it "persists pricing unit usages" do
            travel_to(Time.zone.parse("2023-04-01")) do
              charge.update!(min_amount_cents: 1000)
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.map(&:pricing_unit_usage)).to all be_persisted
            end
          end
        end
      end

      context "with negative units" do
        let(:charge) do
          create(
            :graduated_charge,
            plan: subscription.plan,
            charge_model: "graduated",
            billable_metric:,
            properties: {
              graduated_ranges: [
                {
                  from_value: 0,
                  to_value: nil,
                  per_unit_amount: "0.01",
                  flat_amount: "0.01"
                }
              ]
            }
          )
        end

        let(:billable_metric) { create(:weighted_sum_billable_metric, organization:) }

        before do
          create(
            :event,
            organization: subscription.organization,
            subscription:,
            code: billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"),
            properties: {value: -10}
          )
        end

        it "creates a fee with 0 units but expected amount details" do
          result = charge_subscription_service.call
          expect(result).to be_success
          expect(result.fees.first).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_cents: 0,
            precise_amount_cents: 0.0,
            taxes_precise_amount_cents: 0.0,
            amount_currency: "EUR",
            units: 0,
            total_aggregated_units: -10.0,
            unit_amount_cents: 0,
            precise_unit_amount: 0,
            events_count: 1,
            payment_status: "pending",
            amount_details: {
              "graduated_ranges" => [
                {
                  "flat_unit_amount" => "0.01",
                  "from_value" => 0,
                  "per_unit_amount" => "0.01",
                  "per_unit_total_amount" => "-0.051612903225806452",
                  "to_value" => nil,
                  "total_with_flat_amount" => "-0.041612903225806452",
                  "units" => "-5.1612903225806452"
                }
              ]
            }
          )
        end
      end
    end

    context "with standard charge, all types of aggregation and presence of filter" do
      let(:region) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa])
      end

      let(:country) do
        create(:billable_metric_filter, billable_metric:, key: "country", values: %w[france])
      end

      let(:europe_filter) { create(:charge_filter, charge:, properties: {amount: "20"}) }
      let(:europe_filter_value) do
        create(:charge_filter_value, charge_filter: europe_filter, billable_metric_filter: region, values: ["europe"])
      end

      let(:usa_filter) { create(:charge_filter, charge:, properties: {amount: "50"}) }
      let(:usa_filter_value) do
        create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
      end

      let(:france_filter) { create(:charge_filter, charge:, properties: {amount: "10.12345"}) }
      let(:france_filter_value) do
        create(:charge_filter_value, charge_filter: france_filter, billable_metric_filter: country, values: ["france"])
      end

      let(:charge) do
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {amount: "10.12345"}
        )
      end

      before do
        europe_filter_value
        usa_filter_value
        france_filter_value

        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "usa", foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 10}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 5}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {country: "france", foo_bar: 5}
        )
      end

      it "creates expected fees for count_agg aggregation type" do
        billable_metric.update!(aggregation_type: :count_agg)
        result = charge_subscription_service.call
        expect(result).to be_success
        created_fees = result.fees

        expect(created_fees.count).to eq(4)
        expect(created_fees).to all(
          have_attributes(
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_currency: "EUR"
          )
        )
        expect(created_fees.first).to have_attributes(
          charge_filter: europe_filter,
          amount_cents: 4000,
          precise_amount_cents: 4000.0,
          taxes_precise_amount_cents: 0.0,
          units: 2,
          unit_amount_cents: 2000,
          precise_unit_amount: 20
        )

        expect(created_fees.second).to have_attributes(
          charge_filter: usa_filter,
          amount_cents: 5000,
          precise_amount_cents: 5000.0,
          taxes_precise_amount_cents: 0.0,
          units: 1,
          unit_amount_cents: 5000,
          precise_unit_amount: 50
        )

        expect(created_fees.third).to have_attributes(
          charge_filter: france_filter,
          amount_cents: 1012,
          precise_amount_cents: 1012.345,
          taxes_precise_amount_cents: 0.0,
          units: 1,
          unit_amount_cents: 1012,
          precise_unit_amount: 10.12345
        )
      end

      it "creates expected fees for sum_agg aggregation type" do
        billable_metric.update!(aggregation_type: :sum_agg, field_name: "foo_bar")
        result = charge_subscription_service.call
        expect(result).to be_success
        created_fees = result.fees

        expect(created_fees.count).to eq(4)
        expect(created_fees).to all(
          have_attributes(
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_currency: "EUR"
          )
        )
        expect(created_fees.first).to have_attributes(
          charge_filter: europe_filter,
          amount_cents: 30_000,
          precise_amount_cents: 30_000.0,
          taxes_precise_amount_cents: 0.0,
          units: 15,
          unit_amount_cents: 2000,
          precise_unit_amount: 20
        )

        expect(created_fees.second).to have_attributes(
          charge_filter: usa_filter,
          amount_cents: 60_000,
          precise_amount_cents: 60_000.0,
          taxes_precise_amount_cents: 0.0,
          units: 12,
          unit_amount_cents: 5000,
          precise_unit_amount: 50
        )

        expect(created_fees.third).to have_attributes(
          charge_filter: france_filter,
          amount_cents: 5062,
          precise_amount_cents: 5061.725,
          taxes_precise_amount_cents: 0.0,
          units: 5,
          unit_amount_cents: 1012,
          precise_unit_amount: 10.12345
        )
      end

      it "creates expected fees for max_agg aggregation type" do
        billable_metric.update!(aggregation_type: :max_agg, field_name: "foo_bar")
        result = charge_subscription_service.call
        expect(result).to be_success
        created_fees = result.fees

        expect(created_fees.count).to eq(4)
        expect(created_fees).to all(
          have_attributes(
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_currency: "EUR"
          )
        )
        expect(created_fees.first).to have_attributes(
          charge_filter: europe_filter,
          amount_cents: 20_000,
          precise_amount_cents: 20_000.0,
          taxes_precise_amount_cents: 0.0,
          units: 10,
          unit_amount_cents: 2000,
          precise_unit_amount: 20
        )

        expect(created_fees.second).to have_attributes(
          charge_filter: usa_filter,
          amount_cents: 60_000,
          precise_amount_cents: 60_000.0,
          taxes_precise_amount_cents: 0.0,
          units: 12,
          unit_amount_cents: 5000,
          precise_unit_amount: 50
        )

        expect(created_fees.third).to have_attributes(
          charge_filter: france_filter,
          amount_cents: 5062,
          precise_amount_cents: 5061.725,
          taxes_precise_amount_cents: 0.0,
          units: 5,
          unit_amount_cents: 1012,
          precise_unit_amount: 10.12345
        )
      end

      context "when unique_count_agg" do
        it "creates expected fees for unique_count_agg aggregation type", transaction: false do
          billable_metric.update!(aggregation_type: :unique_count_agg, field_name: "foo_bar")
          result = charge_subscription_service.call
          expect(result).to be_success
          created_fees = result.fees

          expect(created_fees.count).to eq(4)
          expect(created_fees).to all(
            have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_currency: "EUR"
            )
          )
          expect(created_fees.first).to have_attributes(
            charge_filter: europe_filter,
            amount_cents: 4000,
            precise_amount_cents: 4_000.0,
            taxes_precise_amount_cents: 0.0,
            units: 2
          )

          expect(created_fees.second).to have_attributes(
            charge_filter: usa_filter,
            amount_cents: 5000,
            precise_amount_cents: 5_000.0,
            taxes_precise_amount_cents: 0.0,
            units: 1
          )

          expect(created_fees.third).to have_attributes(
            charge_filter: france_filter,
            amount_cents: 1012,
            precise_amount_cents: 1012.345,
            taxes_precise_amount_cents: 0.0,
            units: 1,
            unit_amount_cents: 1012,
            precise_unit_amount: 10.12345
          )
        end
      end
    end

    context "with package charge and presence of filters" do
      let(:region) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa])
      end

      let(:country) do
        create(:billable_metric_filter, billable_metric:, key: "country", values: %w[france])
      end

      let(:europe_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            amount: "100",
            free_units: 1,
            package_size: 8
          }
        )
      end
      let(:europe_filter_value) do
        create(
          :charge_filter_value,
          charge_filter: europe_filter,
          billable_metric_filter: region,
          values: ["europe"]
        )
      end

      let(:usa_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            amount: "50",
            free_units: 0,
            package_size: 10
          }
        )
      end
      let(:usa_filter_value) do
        create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
      end

      let(:france_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            amount: "40",
            free_units: 1,
            package_size: 5
          }
        )
      end
      let(:france_filter_value) do
        create(
          :charge_filter_value,
          charge_filter: france_filter,
          billable_metric_filter: country,
          values: ["france"]
        )
      end

      let(:charge) do
        create(
          :package_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {
            amount: "0",
            free_units: 0,
            package_size: 1
          }
        )
      end

      before do
        europe_filter_value
        usa_filter_value
        france_filter_value

        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "usa", foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 10}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 5}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {country: "france", foo_bar: 5}
        )
      end

      it "creates expected fees for count_agg aggregation type" do
        billable_metric.update!(aggregation_type: :count_agg)
        result = charge_subscription_service.call
        expect(result).to be_success
        created_fees = result.fees

        expect(created_fees.count).to eq(4)
        expect(created_fees).to all(
          have_attributes(
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_currency: "EUR"
          )
        )
        expect(created_fees.first).to have_attributes(
          charge_filter: europe_filter,
          units: 2,
          amount_cents: 10_000,
          precise_amount_cents: 10_000.0,
          taxes_precise_amount_cents: 0.0,
          unit_amount_cents: 10_000,
          precise_unit_amount: 100
        )

        expect(created_fees.second).to have_attributes(
          charge_filter: usa_filter,
          amount_cents: 5000,
          precise_amount_cents: 5_000.0,
          taxes_precise_amount_cents: 0.0,
          units: 1,
          unit_amount_cents: 5000,
          precise_unit_amount: 50
        )

        expect(created_fees.third).to have_attributes(
          charge_filter: france_filter,
          amount_cents: 0,
          precise_amount_cents: 0.0,
          taxes_precise_amount_cents: 0.0,
          units: 1,
          unit_amount_cents: 0,
          precise_unit_amount: 0
        )
      end
    end

    context "with percentage charge and presence of filters" do
      let(:region) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa])
      end

      let(:country) do
        create(:billable_metric_filter, billable_metric:, key: "country", values: %w[france])
      end

      let(:europe_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {rate: "2", fixed_amount: "1"}
        )
      end
      let(:europe_filter_value) do
        create(
          :charge_filter_value,
          charge_filter: europe_filter,
          billable_metric_filter: region,
          values: ["europe"]
        )
      end

      let(:usa_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {rate: "1", fixed_amount: "0"}
        )
      end
      let(:usa_filter_value) do
        create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
      end

      let(:france_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {rate: "5", fixed_amount: "1"}
        )
      end
      let(:france_filter_value) do
        create(
          :charge_filter_value,
          charge_filter: france_filter,
          billable_metric_filter: country,
          values: ["france"]
        )
      end

      let(:charge) do
        create(
          :percentage_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {rate: "0", fixed_amount: "0"}
        )
      end

      before do
        europe_filter_value
        usa_filter_value
        france_filter_value

        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "usa", foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 10}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 5}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {country: "france", foo_bar: 5}
        )
      end

      it "creates expected fees for count_agg aggregation type" do
        billable_metric.update!(aggregation_type: :count_agg)
        result = charge_subscription_service.call
        expect(result).to be_success
        created_fees = result.fees

        expect(created_fees.count).to eq(4)
        expect(created_fees).to all(
          have_attributes(
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_currency: "EUR"
          )
        )
        expect(created_fees.first).to have_attributes(
          charge_filter: europe_filter,
          amount_cents: 200 + 2 * 2,
          precise_amount_cents: 200.0 + 2 * 2,
          taxes_precise_amount_cents: 0.0,
          units: 2,
          unit_amount_cents: 102,
          precise_unit_amount: 1.02
        )

        expect(created_fees.second).to have_attributes(
          charge_filter: usa_filter,
          amount_cents: 1 * 1,
          precise_amount_cents: 1.0 * 1,
          taxes_precise_amount_cents: 0.0,
          units: 1,
          unit_amount_cents: 1,
          precise_unit_amount: 0.01
        )

        expect(created_fees.third).to have_attributes(
          charge_filter: france_filter,
          amount_cents: 100 + 5 * 1,
          precise_amount_cents: 100.0 + 5.0 * 1,
          taxes_precise_amount_cents: 0.0,
          units: 1,
          unit_amount_cents: 105,
          precise_unit_amount: 1.05
        )
      end
    end

    context "with graduated charge and presence of filters" do
      let(:region) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa])
      end

      let(:europe_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: nil,
                per_unit_amount: "0.01",
                flat_amount: "0.01"
              }
            ]
          }
        )
      end
      let(:europe_filter_value) do
        create(
          :charge_filter_value,
          charge_filter: europe_filter,
          billable_metric_filter: region,
          values: ["europe"]
        )
      end

      let(:usa_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: nil,
                per_unit_amount: "0.03",
                flat_amount: "0.01"
              }
            ]
          }
        )
      end
      let(:usa_filter_value) do
        create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
      end

      let(:charge) do
        create(
          :graduated_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: nil,
                per_unit_amount: "0",
                flat_amount: "0"
              }
            ]
          }
        )
      end

      before do
        europe_filter_value
        usa_filter_value

        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "usa", foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 10}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 5}
        )
      end

      context "without pricing unit on the charge" do
        it "creates expected fees for count_agg aggregation type" do
          billable_metric.update!(aggregation_type: :count_agg)
          result = charge_subscription_service.call
          expect(result).to be_success
          created_fees = result.fees

          expect(created_fees.count).to eq(3)
          expect(created_fees).to all(
            have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_currency: "EUR"
            )
          )
          expect(created_fees.first).to have_attributes(
            charge_filter: europe_filter,
            amount_cents: 3,
            precise_amount_cents: 3.0,
            taxes_precise_amount_cents: 0.0,
            units: 2,
            unit_amount_cents: 1,
            precise_unit_amount: 0.015
          )

          expect(created_fees.second).to have_attributes(
            charge_filter: usa_filter,
            amount_cents: 4,
            precise_amount_cents: 4.0,
            taxes_precise_amount_cents: 0.0,
            units: 1,
            unit_amount_cents: 4,
            precise_unit_amount: 0.04
          )
        end

        it "does not create pricing unit usage" do
          expect { charge_subscription_service.call }.not_to change(PricingUnitUsage, :count)
        end
      end

      context "with pricing unit on the charge" do
        before do
          create(
            :applied_pricing_unit,
            organization: subscription.organization,
            conversion_rate: 2,
            pricing_unitable: charge
          )
        end

        it "creates expected fees for count_agg aggregation type" do
          billable_metric.update!(aggregation_type: :count_agg)
          result = charge_subscription_service.call
          expect(result).to be_success
          created_fees = result.fees

          expect(created_fees.count).to eq(3)
          expect(created_fees).to all(
            have_attributes(
              invoice_id: invoice.id,
              charge_id: charge.id,
              amount_currency: "EUR"
            )
          )

          expect(created_fees.first).to have_attributes(
            charge_filter: europe_filter,
            amount_cents: 6,
            precise_amount_cents: 6.0,
            taxes_precise_amount_cents: 0.0,
            units: 2,
            unit_amount_cents: 2,
            precise_unit_amount: 0.02
          )

          expect(created_fees.first.pricing_unit_usage)
            .to be_persisted
            .and have_attributes(
              amount_cents: 3,
              precise_amount_cents: 3.0,
              unit_amount_cents: 1
            )

          expect(created_fees.second).to have_attributes(
            charge_filter: usa_filter,
            amount_cents: 8,
            precise_amount_cents: 8.0,
            taxes_precise_amount_cents: 0.0,
            units: 1,
            unit_amount_cents: 8,
            precise_unit_amount: 0.08
          )

          expect(created_fees.second.pricing_unit_usage)
            .to be_persisted
            .and have_attributes(
              amount_cents: 4,
              precise_amount_cents: 4.0,
              unit_amount_cents: 4
            )
        end
      end
    end

    context "with volume charge and presence of filters" do
      let(:region) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa])
      end

      let(:europe_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            volume_ranges: [
              {from_value: 0, to_value: nil, per_unit_amount: "2", flat_amount: "10"}
            ]
          }
        )
      end
      let(:europe_filter_value) do
        create(
          :charge_filter_value,
          charge_filter: europe_filter,
          billable_metric_filter: region,
          values: ["europe"]
        )
      end

      let(:usa_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            volume_ranges: [
              {from_value: 0, to_value: nil, per_unit_amount: "1", flat_amount: "10"}
            ]
          }
        )
      end
      let(:usa_filter_value) do
        create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
      end

      let(:charge) do
        create(
          :volume_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {
            volume_ranges: [
              {from_value: 0, to_value: nil, per_unit_amount: "0", flat_amount: "0"}
            ]
          }
        )
      end

      before do
        europe_filter_value
        usa_filter_value

        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "usa", foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 10}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 5}
        )
      end

      it "creates expected fees for count_agg aggregation type" do
        billable_metric.update!(aggregation_type: :count_agg)
        result = charge_subscription_service.call
        expect(result).to be_success
        created_fees = result.fees

        expect(created_fees.count).to eq(3)
        expect(created_fees).to all(
          have_attributes(
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_currency: "EUR"
          )
        )
        expect(created_fees.first).to have_attributes(
          charge_filter: europe_filter,
          amount_cents: 1400,
          precise_amount_cents: 1_400.0,
          taxes_precise_amount_cents: 0.0,
          units: 2,
          unit_amount_cents: 700,
          precise_unit_amount: 7
        )

        expect(created_fees.second).to have_attributes(
          charge_filter: usa_filter,
          amount_cents: 1100,
          precise_amount_cents: 1_100.0,
          taxes_precise_amount_cents: 0.0,
          units: 1,
          unit_amount_cents: 1100,
          precise_unit_amount: 11
        )
      end
    end

    context "with graduated percentage charge and presence of filters" do
      let(:region) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa])
      end

      let(:europe_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            graduated_percentage_ranges: [
              {
                from_value: 0,
                to_value: nil,
                flat_amount: "0.01",
                rate: "2"
              }
            ]
          }
        )
      end
      let(:europe_filter_value) do
        create(
          :charge_filter_value,
          charge_filter: europe_filter,
          billable_metric_filter: region,
          values: ["europe"]
        )
      end

      let(:usa_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {
            graduated_percentage_ranges: [
              {
                from_value: 0,
                to_value: nil,
                flat_amount: "0.01",
                rate: "3"
              }
            ]
          }
        )
      end
      let(:usa_filter_value) do
        create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
      end

      let(:charge) do
        create(
          :graduated_percentage_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {
            graduated_percentage_ranges: [
              {
                from_value: 0,
                to_value: nil,
                flat_amount: "1",
                rate: "0"
              }
            ]
          }
        )
      end

      before do
        europe_filter_value
        usa_filter_value

        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "usa", foo_bar: 12}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 10}
        )
        create(
          :event,
          organization: subscription.organization,
          subscription:,
          code: charge.billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "europe", foo_bar: 5}
        )
      end

      it "creates expected fees for count_agg aggregation type" do
        billable_metric.update!(aggregation_type: :count_agg)
        result = charge_subscription_service.call
        expect(result).to be_success
        created_fees = result.fees

        expect(created_fees.count).to eq(3)
        expect(created_fees).to all(
          have_attributes(
            invoice_id: invoice.id,
            charge_id: charge.id,
            amount_currency: "EUR"
          )
        )
        expect(created_fees.first).to have_attributes(
          charge_filter: europe_filter,
          amount_cents: 5, # 2 × 0.02 + 0.01
          precise_amount_cents: 5.0,
          taxes_precise_amount_cents: 0.0,
          units: 2,
          unit_amount_cents: 2,
          precise_unit_amount: 0.025
        )

        expect(created_fees.second).to have_attributes(
          charge_filter: usa_filter,
          amount_cents: 4, # 1 × 0.03 + 0.01
          precise_amount_cents: 4.0,
          taxes_precise_amount_cents: 0.0,
          units: 1,
          unit_amount_cents: 4,
          precise_unit_amount: 0.04
        )
      end
    end

    context "with true-up fee and presence of filters" do
      let(:region) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa])
      end

      let(:europe_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {amount: "20"}
        )
      end
      let(:europe_filter_value) do
        create(
          :charge_filter_value,
          charge_filter: europe_filter,
          billable_metric_filter: region,
          values: ["europe"]
        )
      end

      let(:usa_filter) do
        create(
          :charge_filter,
          charge:,
          properties: {amount: "50"}
        )
      end
      let(:usa_filter_value) do
        create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
      end

      let(:charge) do
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric:,
          min_amount_cents: 1000,
          properties: {amount: "0"}
        )
      end

      before do
        europe_filter_value
        usa_filter_value
      end

      it "creates two fees" do
        travel_to(Time.zone.parse("2023-04-01")) do
          result = charge_subscription_service.call

          expect(result).to be_success
          expect(result.fees.count).to eq(2)

          # 548 is 1000 prorated for 17 days.
          expect(result.fees.pluck(:amount_cents)).to contain_exactly(0, 548)
          expect(result.fees.pluck(:precise_amount_cents)).to contain_exactly(0, 548.3870967741935)
          expect(result.fees.pluck(:taxes_precise_amount_cents)).to contain_exactly(0.0, 0.0)
        end
      end
    end

    context "with recurring weighted sum aggregation" do
      let(:context) { :recurring }
      let(:billable_metric) { create(:weighted_sum_billable_metric, :recurring, organization:) }

      it "creates a fee and a cached aggregation" do
        result = charge_subscription_service.call
        expect(result).to be_success
        created_fee = result.fees.first
        cached_aggregation = result.cached_aggregations.first

        expect(created_fee.id).not_to be_nil
        expect(created_fee.invoice_id).to eq(invoice.id)
        expect(created_fee.charge_id).to eq(charge.id)
        expect(created_fee.amount_cents).to eq(0)
        expect(created_fee.precise_amount_cents).to eq(0.0)
        expect(created_fee.taxes_precise_amount_cents).to eq(0.0)
        expect(created_fee.amount_currency).to eq("EUR")
        expect(created_fee.units).to eq(0)
        expect(created_fee.total_aggregated_units).to eq(0)
        expect(created_fee.events_count).to eq(0)
        expect(created_fee.payment_status).to eq("pending")

        expect(cached_aggregation.id).not_to be_nil
        expect(cached_aggregation.organization).to eq(organization)
        expect(cached_aggregation.external_subscription_id).to eq(subscription.external_id)
        expect(cached_aggregation.charge_filter_id).to be_nil
        expect(cached_aggregation.charge_id).to eq(charge.id)
        expect(cached_aggregation.timestamp).to eq(boundaries.from_datetime)
        expect(cached_aggregation.current_aggregation).to eq(0.0)
      end

      context "with presentation_group_keys" do
        let(:charge) do
          create(
            :standard_charge,
            plan: subscription.plan,
            billable_metric:,
            properties: {
              amount: "20",
              presentation_group_keys: [{value: "region"}]
            }
          )
        end

        before do
          create(:event, organization: subscription.organization, subscription:, code: billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"), properties: {region: "us-east-1", value: 10})
          create(:event, organization: subscription.organization, subscription:, code: billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"), properties: {region: "eu-west-1", value: 5})
        end

        it "stores presentation_breakdowns on the cached aggregation" do
          result = charge_subscription_service.call
          expect(result).to be_success

          cached_aggregation = result.cached_aggregations.first
          expect(cached_aggregation.presentation_breakdowns.map { |b| b["groups"] }).to match_array(
            [{"region" => "us-east-1"}, {"region" => "eu-west-1"}]
          )
          expect(cached_aggregation.presentation_breakdowns.map { |b| b["value"].to_f.round(5) }).to eq([2.58065, 5.16129])
        end
      end
    end

    context "with aggregation error" do
      let(:billable_metric) do
        create(
          :billable_metric,
          aggregation_type: "max_agg",
          field_name: "foo_bar"
        )
      end
      let(:aggregator_service) { instance_double(BillableMetrics::Aggregations::MaxService) }
      let(:error_result) do
        BaseService::Result.new.service_failure!(code: "aggregation_failure", message: "Test message")
      end

      it "returns an error" do
        allow(BillableMetrics::Aggregations::MaxService).to receive(:new)
          .and_return(aggregator_service)
        allow(aggregator_service).to receive(:aggregate)
          .and_return(error_result)

        result = charge_subscription_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("aggregation_failure")
        expect(result.error.error_message).to eq("Test message")

        expect(BillableMetrics::Aggregations::MaxService).to have_received(:new)
        expect(aggregator_service).to have_received(:aggregate)
      end
    end

    context "when current usage" do
      let(:context) { :current_usage }

      context "when charge uses presentation_group_keys" do
        let(:billable_metric) do
          create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
        end

        let(:charge) do
          create(
            :standard_charge,
            plan: subscription.plan,
            billable_metric:,
            properties: {
              amount: "0",
              presentation_group_keys: [{value: "region"}]
            }
          )
        end

        let(:region) do
          create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa apac])
        end

        let(:europe_filter) do
          create(
            :charge_filter,
            charge:,
            properties: {
              amount: "0",
              presentation_group_keys: [{value: "region"}]
            }
          )
        end

        let(:usa_filter) do
          create(
            :charge_filter,
            charge:,
            properties: {
              amount: "0",
              presentation_group_keys: [{value: "region"}]
            }
          )
        end

        before do
          create(:charge_filter_value, charge_filter: europe_filter, billable_metric_filter: region, values: ["europe"])
          create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])

          create(
            :event,
            organization:,
            subscription:,
            code: billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"),
            properties: {region: "europe", value: 10}
          )
          create(
            :event,
            organization:,
            subscription:,
            code: billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"),
            properties: {region: "usa", value: 5}
          )
          create(
            :event,
            organization:,
            subscription:,
            code: billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"),
            properties: {region: "apac", value: 3}
          )
        end

        it "builds presentation_breakdowns on each non-persisted fee" do
          expect { charge_subscription_service.call }.not_to change(Fee, :count)

          result = charge_subscription_service.call

          europe_fee = result.fees.find { |f| f.charge_filter_id == europe_filter.id }
          usa_fee = result.fees.find { |f| f.charge_filter_id == usa_filter.id }
          catch_all_fee = result.fees.find { |f| f.charge_filter_id.nil? }

          expect(europe_fee.presentation_breakdowns.map(&:presentation_by)).to match_array([{"region" => "europe"}])
          expect(usa_fee.presentation_breakdowns.map(&:presentation_by)).to match_array([{"region" => "usa"}])
          expect(catch_all_fee.presentation_breakdowns.map(&:presentation_by)).to match_array([{"region" => "apac"}])

          expect(europe_fee.presentation_breakdowns.map { |b| b.units.to_f }).to match_array([10.0])
          expect(usa_fee.presentation_breakdowns.map { |b| b.units.to_f }).to match_array([5.0])
          expect(catch_all_fee.presentation_breakdowns.map { |b| b.units.to_f }).to match_array([3.0])

          expect(result.fees.flat_map(&:presentation_breakdowns)).to all(have_attributes(organization_id: organization.id))
        end
      end

      context "with all types of aggregation" do
        BillableMetric::AGGREGATION_TYPES.keys.each do |aggregation_type|
          before do
            billable_metric.update!(
              aggregation_type:,
              field_name: "foo_bar",
              weighted_interval: "seconds",
              custom_aggregator: "def aggregate(event, agg, aggregation_properties); agg; end"
            )

            charge.update!(min_amount_cents: 1000)

            allow(AdjustedFee).to receive(:where).and_call_original
          end

          it "initializes fees" do
            result = charge_subscription_service.call

            expect(result).to be_success

            usage_fee = result.fees.first

            expect(result.fees.count).to eq(1)
            expect(usage_fee.id).to be_nil
            expect(usage_fee.invoice_id).to eq(invoice.id)
            expect(usage_fee.charge_id).to eq(charge.id)
            expect(usage_fee.amount_cents).to eq(0)
            expect(usage_fee.precise_amount_cents).to eq(0.0)
            expect(usage_fee.taxes_precise_amount_cents).to eq(0.0)
            expect(usage_fee.amount_currency).to eq("EUR")
            expect(usage_fee.units).to eq(0)
          end

          it "loads adjusted fees only once for the persistable-fee check" do
            charge_subscription_service.call

            expect(AdjustedFee).to have_received(:where).once
          end
        end
      end

      context "with graduated charge model" do
        let(:charge) do
          create(
            :graduated_charge,
            plan: subscription.plan,
            charge_model: "graduated",
            billable_metric:,
            properties: {
              graduated_ranges: [
                {
                  from_value: 0,
                  to_value: nil,
                  per_unit_amount: "0.01",
                  flat_amount: "0.01"
                }
              ]
            }
          )
        end

        before do
          create_list(
            :event,
            4,
            organization: subscription.organization,
            subscription:,
            code: charge.billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16")
          )
        end

        it "initialize a fee" do
          result = charge_subscription_service.call

          expect(result).to be_success

          usage_fee = result.fees.first

          expect(usage_fee.id).to be_nil
          expect(usage_fee.invoice_id).to eq(invoice.id)
          expect(usage_fee.charge_id).to eq(charge.id)
          expect(usage_fee.amount_cents).to eq(5)
          expect(usage_fee.precise_amount_cents).to eq(5.0)
          expect(usage_fee.taxes_precise_amount_cents).to eq(0.0)
          expect(usage_fee.amount_currency).to eq("EUR")
          expect(usage_fee.units.to_s).to eq("4.0")
        end
      end

      context "with aggregation error" do
        let(:billable_metric) do
          create(
            :billable_metric,
            aggregation_type: "max_agg",
            field_name: "foo_bar"
          )
        end
        let(:aggregator_service) { instance_double(BillableMetrics::Aggregations::MaxService) }
        let(:error_result) do
          BaseService::Result.new.service_failure!(code: "aggregation_failure", message: "Test message")
        end

        it "returns an error" do
          allow(BillableMetrics::Aggregations::MaxService).to receive(:new)
            .and_return(aggregator_service)
          allow(aggregator_service).to receive(:aggregate)
            .and_return(error_result)

          result = charge_subscription_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("aggregation_failure")
          expect(result.error.error_message).to eq("Test message")

          expect(BillableMetrics::Aggregations::MaxService).to have_received(:new)
          expect(aggregator_service).to have_received(:aggregate)
        end
      end

      context "with non-persistable fees" do
        context "when all fees are zero" do
          it "returns a zero fee" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.count).to eq(1)
            expect(result.fees.first).to have_attributes(
              units: 0,
              amount_cents: 0,
              precise_amount_cents: 0.0,
              unit_amount_cents: 0,
              precise_unit_amount: 0,
              events_count: 0,
              grouped_by: {},
              charge_filter_id: nil,
              pay_in_advance: false,
              amount_currency: "EUR"
            )
          end

          context "with graduated charge model" do
            let(:charge) do
              create(
                :graduated_charge,
                plan: subscription.plan,
                billable_metric:,
                properties: {
                  graduated_ranges: [
                    {from_value: 0, to_value: 10, per_unit_amount: "2", flat_amount: "100"},
                    {from_value: 11, to_value: nil, per_unit_amount: "1", flat_amount: "50"}
                  ]
                }
              )
            end

            it "returns zero fee with graduated amount_details" do
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.count).to eq(1)
              expect(result.fees.first).to have_attributes(
                units: 0,
                amount_cents: 0,
                precise_amount_cents: 0.0,
                unit_amount_cents: 0,
                precise_unit_amount: 0,
                events_count: 0,
                grouped_by: {},
                charge_filter_id: nil,
                pay_in_advance: false,
                amount_currency: "EUR"
              )
              expect(result.fees.first.amount_details).to eq(
                "graduated_ranges" => [
                  {
                    "from_value" => 0,
                    "to_value" => 10,
                    "flat_unit_amount" => "0.0",
                    "per_unit_amount" => "0.0",
                    "units" => "0.0",
                    "per_unit_total_amount" => "0.0",
                    "total_with_flat_amount" => "0.0"
                  }
                ]
              )
            end
          end

          context "with package charge model" do
            let(:charge) do
              create(
                :package_charge,
                plan: subscription.plan,
                billable_metric:,
                properties: {amount: "100", free_units: 10, package_size: 10}
              )
            end

            it "returns zero fee with package amount_details" do
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.count).to eq(1)
              expect(result.fees.first).to have_attributes(
                units: 0,
                amount_cents: 0,
                precise_amount_cents: 0.0,
                unit_amount_cents: 0,
                precise_unit_amount: 0,
                events_count: 0,
                grouped_by: {},
                charge_filter_id: nil,
                pay_in_advance: false,
                amount_currency: "EUR"
              )
              expect(result.fees.first.amount_details).to eq(
                "free_units" => "0.0",
                "paid_units" => "0.0",
                "per_package_size" => 0,
                "per_package_unit_amount" => "0.0"
              )
            end
          end

          context "with percentage charge model" do
            let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }
            let(:charge) do
              create(
                :percentage_charge,
                plan: subscription.plan,
                billable_metric:,
                properties: {rate: "0.05", fixed_amount: "2"}
              )
            end

            it "returns zero fee with percentage amount_details" do
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.count).to eq(1)
              expect(result.fees.first).to have_attributes(
                units: 0,
                amount_cents: 0,
                precise_amount_cents: 0.0,
                unit_amount_cents: 0,
                precise_unit_amount: 0,
                events_count: 0,
                grouped_by: {},
                charge_filter_id: nil,
                pay_in_advance: false,
                amount_currency: "EUR"
              )
              expect(result.fees.first.amount_details).to eq(
                "units" => "0.0",
                "free_units" => "0.0",
                "free_events" => 0,
                "paid_units" => "0.0",
                "rate" => "0.05",
                "per_unit_total_amount" => "0.0",
                "paid_events" => 0,
                "fixed_fee_unit_amount" => "0.0",
                "fixed_fee_total_amount" => "0.0",
                "min_max_adjustment_total_amount" => "0.0"
              )
            end
          end

          context "with volume charge model" do
            let(:charge) do
              create(
                :volume_charge,
                plan: subscription.plan,
                billable_metric:,
                properties: {
                  volume_ranges: [
                    {from_value: 0, to_value: 100, per_unit_amount: "2", flat_amount: "1"},
                    {from_value: 101, to_value: nil, per_unit_amount: "1", flat_amount: "0"}
                  ]
                }
              )
            end

            it "returns zero fee with volume amount_details" do
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.count).to eq(1)
              expect(result.fees.first).to have_attributes(
                units: 0,
                amount_cents: 0,
                precise_amount_cents: 0.0,
                unit_amount_cents: 0,
                precise_unit_amount: 0,
                events_count: 0,
                grouped_by: {},
                charge_filter_id: nil,
                pay_in_advance: false,
                amount_currency: "EUR"
              )
              expect(result.fees.first.amount_details).to eq(
                "flat_unit_amount" => "0.0",
                "per_unit_amount" => "0.0",
                "per_unit_total_amount" => "0.0"
              )
            end
          end

          context "with graduated_percentage charge model" do
            let(:charge) do
              create(
                :graduated_percentage_charge,
                plan: subscription.plan,
                billable_metric:,
                properties: {
                  graduated_percentage_ranges: [
                    {from_value: 0, to_value: 10, rate: "1", flat_amount: "100"},
                    {from_value: 11, to_value: nil, rate: "0.5", flat_amount: "50"}
                  ]
                }
              )
            end

            it "returns zero fee with graduated_percentage amount_details" do
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.count).to eq(1)
              expect(result.fees.first).to have_attributes(
                units: 0,
                amount_cents: 0,
                precise_amount_cents: 0.0,
                unit_amount_cents: 0,
                precise_unit_amount: 0,
                events_count: 0,
                grouped_by: {},
                charge_filter_id: nil,
                pay_in_advance: false,
                amount_currency: "EUR"
              )
              expect(result.fees.first.amount_details).to eq(
                "graduated_percentage_ranges" => [
                  {
                    "from_value" => 0,
                    "to_value" => 10,
                    "flat_unit_amount" => "0.0",
                    "rate" => "1.0",
                    "units" => "0.0",
                    "per_unit_total_amount" => "0.0",
                    "total_with_flat_amount" => "0.0"
                  }
                ]
              )
            end
          end
        end

        context "when some fees are non-zero" do
          before do
            create(
              :event,
              organization:,
              subscription:,
              code: billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16")
            )
          end

          it "returns the fees" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.count).to eq(1)
            expect(result.fees.first.units).to eq(1)
          end
        end

        context "when fee has zero units and amount but non-zero events_count" do
          let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

          before do
            create(
              :event,
              organization:,
              subscription:,
              code: billable_metric.code,
              timestamp: Time.zone.parse("2022-03-16"),
              properties: {value: 0}
            )
          end

          it "returns the fee because events_count is non-zero" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.count).to eq(1)
            expect(result.fees.first).to have_attributes(
              units: 0,
              amount_cents: 0,
              events_count: 1
            )
          end
        end

        context "when fee has an adjusted_fee" do
          let(:adjusted_fee) do
            create(
              :adjusted_fee,
              invoice:,
              subscription:,
              charge:,
              properties: {
                charges_from_datetime: boundaries.charges_from_datetime,
                charges_to_datetime: boundaries.charges_to_datetime
              },
              fee_type: :charge,
              adjusted_units: true,
              adjusted_amount: false,
              units: 3
            )
          end

          before do
            adjusted_fee
            invoice.draft!
          end

          it "returns the fee because an adjusted_fee exists" do
            result = charge_subscription_service.call

            expect(result).to be_success
            expect(result.fees.count).to eq(1)
          end
        end

        context "with charge filters" do
          let(:region) { create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa]) }
          let(:europe_filter) { create(:charge_filter, charge:, properties: {amount: "20"}) }
          let(:usa_filter) { create(:charge_filter, charge:, properties: {amount: "50"}) }

          before do
            create(:charge_filter_value, charge_filter: europe_filter, billable_metric_filter: region, values: ["europe"])
            create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
          end

          context "when all filters have zero usage" do
            it "returns zero fees for each filter and catch-all" do
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.count).to eq(3)
              expect(result.fees).to all(have_attributes(units: 0, amount_cents: 0, events_count: 0))
              expect(result.fees.map(&:charge_filter_id)).to match_array([europe_filter.id, usa_filter.id, nil])
            end
          end

          context "when one filter has non-zero usage" do
            before do
              create(
                :event,
                organization:,
                subscription:,
                code: billable_metric.code,
                timestamp: Time.zone.parse("2022-03-16"),
                properties: {region: "europe"}
              )
            end

            it "returns non-zero and zero fees for all filters" do
              result = charge_subscription_service.call

              expect(result).to be_success
              expect(result.fees.count).to eq(3)

              non_zero_fees = result.fees.select { |f| f.units != 0 || f.events_count != 0 }
              expect(non_zero_fees.count).to eq(1)
              expect(non_zero_fees.first.charge_filter).to eq(europe_filter)

              zero_fees = result.fees.select { |f| f.units == 0 && f.events_count == 0 }
              expect(zero_fees.count).to eq(2)
              expect(zero_fees.map(&:charge_filter_id)).to match_array([usa_filter.id, nil])
            end
          end
        end

        context "with cache middleware enabled", cache: :memory do
          subject(:charge_subscription_service) do
            described_class.new(
              invoice:,
              charge:,
              subscription:,
              boundaries:,
              context: :current_usage,
              apply_taxes: false,
              filtered_aggregations: nil,
              cache_middleware:
            )
          end

          let(:cache_middleware) do
            Subscriptions::ChargeCacheMiddleware.new(
              subscription:,
              charge:,
              to_datetime: boundaries.charges_to_datetime,
              cache: true
            )
          end

          let(:cache_key) do
            Subscriptions::ChargeCacheService.new(
              subscription:, charge:, charge_filter: nil
            ).cache_key
          end

          around { |test| travel_to(Time.zone.parse("2022-03-16")) { test.run } }

          before { Rails.cache.clear }

          context "when all fees are zero" do
            it "caches an empty array" do
              charge_subscription_service.call

              cached_value = Rails.cache.read(cache_key)
              expect(cached_value).to eq("[]")
            end

            it "returns zero fee on subsequent calls from cache" do
              first_result = charge_subscription_service.call
              second_result = charge_subscription_service.call

              expect(first_result).to be_success
              expect(first_result.fees.count).to eq(1)
              expect(first_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)

              expect(second_result).to be_success
              expect(second_result.fees.count).to eq(1)
              expect(second_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)
            end

            context "with graduated charge model" do
              let(:charge) do
                create(
                  :graduated_charge,
                  plan: subscription.plan,
                  billable_metric:,
                  properties: {
                    graduated_ranges: [
                      {from_value: 0, to_value: 10, per_unit_amount: "2", flat_amount: "100"},
                      {from_value: 11, to_value: nil, per_unit_amount: "1", flat_amount: "50"}
                    ]
                  }
                )
              end

              it "caches empty array and returns zero fee with correct amount_details on subsequent call" do
                charge_subscription_service.call

                cached_value = Rails.cache.read(cache_key)
                expect(cached_value).to eq("[]")

                second_result = charge_subscription_service.call
                expect(second_result).to be_success
                expect(second_result.fees.count).to eq(1)
                expect(second_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)
                expect(second_result.fees.first.amount_details).to eq(
                  "graduated_ranges" => [
                    {
                      "from_value" => 0,
                      "to_value" => 10,
                      "flat_unit_amount" => "0.0",
                      "per_unit_amount" => "0.0",
                      "units" => "0.0",
                      "per_unit_total_amount" => "0.0",
                      "total_with_flat_amount" => "0.0"
                    }
                  ]
                )
              end
            end

            context "with package charge model" do
              let(:charge) do
                create(
                  :package_charge,
                  plan: subscription.plan,
                  billable_metric:,
                  properties: {amount: "100", free_units: 10, package_size: 10}
                )
              end

              it "caches empty array and returns zero fee with correct amount_details on subsequent call" do
                charge_subscription_service.call

                cached_value = Rails.cache.read(cache_key)
                expect(cached_value).to eq("[]")

                second_result = charge_subscription_service.call
                expect(second_result).to be_success
                expect(second_result.fees.count).to eq(1)
                expect(second_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)
                expect(second_result.fees.first.amount_details).to eq(
                  "free_units" => "0.0",
                  "paid_units" => "0.0",
                  "per_package_size" => 0,
                  "per_package_unit_amount" => "0.0"
                )
              end
            end

            context "with percentage charge model" do
              let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }
              let(:charge) do
                create(
                  :percentage_charge,
                  plan: subscription.plan,
                  billable_metric:,
                  properties: {rate: "0.05", fixed_amount: "2"}
                )
              end

              it "caches empty array and returns zero fee with correct amount_details on subsequent call" do
                charge_subscription_service.call

                cached_value = Rails.cache.read(cache_key)
                expect(cached_value).to eq("[]")

                second_result = charge_subscription_service.call
                expect(second_result).to be_success
                expect(second_result.fees.count).to eq(1)
                expect(second_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)
                expect(second_result.fees.first.amount_details).to eq(
                  "units" => "0.0",
                  "free_units" => "0.0",
                  "free_events" => 0,
                  "paid_units" => "0.0",
                  "rate" => "0.05",
                  "per_unit_total_amount" => "0.0",
                  "paid_events" => 0,
                  "fixed_fee_unit_amount" => "0.0",
                  "fixed_fee_total_amount" => "0.0",
                  "min_max_adjustment_total_amount" => "0.0"
                )
              end
            end

            context "with percentage charge model and per transaction min/max", :premium do
              let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }
              let(:charge) do
                create(
                  :percentage_charge,
                  plan: subscription.plan,
                  billable_metric:,
                  properties: {rate: "1", fixed_amount: "1", per_transaction_max_amount: "12", per_transaction_min_amount: "1.75"}
                )
              end

              it "caches empty array and returns zero fee without raising on subsequent call" do
                charge_subscription_service.call

                cached_value = Rails.cache.read(cache_key)
                expect(cached_value).to eq("[]")

                second_result = charge_subscription_service.call
                expect(second_result).to be_success
                expect(second_result.fees.count).to eq(1)
                expect(second_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)
                expect(second_result.fees.first.amount_details).to eq(
                  "units" => "0.0",
                  "free_units" => "0.0",
                  "free_events" => 0,
                  "paid_units" => "0.0",
                  "rate" => "1.0",
                  "per_unit_total_amount" => "0.0",
                  "paid_events" => 0,
                  "fixed_fee_unit_amount" => "0.0",
                  "fixed_fee_total_amount" => "0.0",
                  "min_max_adjustment_total_amount" => "0.0"
                )
              end
            end

            context "with volume charge model" do
              let(:charge) do
                create(
                  :volume_charge,
                  plan: subscription.plan,
                  billable_metric:,
                  properties: {
                    volume_ranges: [
                      {from_value: 0, to_value: 100, per_unit_amount: "2", flat_amount: "1"},
                      {from_value: 101, to_value: nil, per_unit_amount: "1", flat_amount: "0"}
                    ]
                  }
                )
              end

              it "caches empty array and returns zero fee with correct amount_details on subsequent call" do
                charge_subscription_service.call

                cached_value = Rails.cache.read(cache_key)
                expect(cached_value).to eq("[]")

                second_result = charge_subscription_service.call
                expect(second_result).to be_success
                expect(second_result.fees.count).to eq(1)
                expect(second_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)
                expect(second_result.fees.first.amount_details).to eq(
                  "flat_unit_amount" => "0.0",
                  "per_unit_amount" => "0.0",
                  "per_unit_total_amount" => "0.0"
                )
              end
            end

            context "with graduated_percentage charge model" do
              let(:charge) do
                create(
                  :graduated_percentage_charge,
                  plan: subscription.plan,
                  billable_metric:,
                  properties: {
                    graduated_percentage_ranges: [
                      {from_value: 0, to_value: 10, rate: "1", flat_amount: "100"},
                      {from_value: 11, to_value: nil, rate: "0.5", flat_amount: "50"}
                    ]
                  }
                )
              end

              it "caches empty array and returns zero fee with correct amount_details on subsequent call" do
                charge_subscription_service.call

                cached_value = Rails.cache.read(cache_key)
                expect(cached_value).to eq("[]")

                second_result = charge_subscription_service.call
                expect(second_result).to be_success
                expect(second_result.fees.count).to eq(1)
                expect(second_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)
                expect(second_result.fees.first.amount_details).to eq(
                  "graduated_percentage_ranges" => [
                    {
                      "from_value" => 0,
                      "to_value" => 10,
                      "flat_unit_amount" => "0.0",
                      "rate" => "1.0",
                      "units" => "0.0",
                      "per_unit_total_amount" => "0.0",
                      "total_with_flat_amount" => "0.0"
                    }
                  ]
                )
              end
            end

            context "with pricing_group_keys keys" do
              let(:charge) do
                create(
                  :standard_charge,
                  plan: subscription.plan,
                  billable_metric:,
                  properties: {amount: "100", pricing_group_keys: ["region"]}
                )
              end

              it "caches empty array and returns zero fee with correct grouped_by on subsequent call" do
                charge_subscription_service.call

                cached_value = Rails.cache.read(cache_key)
                expect(cached_value).to eq("[]")

                second_result = charge_subscription_service.call
                expect(second_result).to be_success
                expect(second_result.fees.count).to eq(1)
                expect(second_result.fees.first).to have_attributes(units: 0, amount_cents: 0, events_count: 0)
                expect(second_result.fees.first.grouped_by).to eq("region" => nil)
              end
            end
          end

          context "when fees are non-zero" do
            before do
              create(
                :event,
                organization:,
                subscription:,
                code: billable_metric.code,
                timestamp: Time.zone.parse("2022-03-16")
              )
            end

            it "caches the fee data" do
              charge_subscription_service.call

              cached_value = Rails.cache.read(cache_key)
              parsed = JSON.parse(cached_value)
              expect(parsed.length).to eq(1)
              expect(parsed.first["events_count"]).to eq(1)
            end

            context "when charge uses presentation_group_keys" do
              let(:billable_metric) do
                create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
              end

              let(:charge) do
                create(
                  :standard_charge,
                  plan: subscription.plan,
                  billable_metric:,
                  properties: {
                    amount: "20",
                    presentation_group_keys: [{value: "region"}]
                  }
                )
              end

              before do
                create(
                  :event,
                  organization:,
                  subscription:,
                  code: billable_metric.code,
                  timestamp: Time.zone.parse("2022-03-16"),
                  properties: {region: "eu", value: 10}
                )
                create(
                  :event,
                  organization:,
                  subscription:,
                  code: billable_metric.code,
                  timestamp: Time.zone.parse("2022-03-16"),
                  properties: {region: "us", value: 5}
                )
              end

              it "keeps presentation_breakdowns on subsequent calls from cache" do
                first_result = charge_subscription_service.call
                cached_value = Rails.cache.read(cache_key)
                second_result = charge_subscription_service.call

                expect(first_result).to be_success
                expect(first_result.fees.count).to eq(1)
                expect(first_result.fees.first.presentation_breakdowns.map(&:presentation_by)).to match_array(
                  [{"region" => "eu"}, {"region" => "us"}]
                )

                expect(JSON.parse(cached_value).first["presentation_breakdowns"]).to match_array(
                  [
                    hash_including({"presentation_by" => {"region" => "eu"}, "units" => "10.0", "organization_id" => organization.id}),
                    hash_including({"presentation_by" => {"region" => "us"}, "units" => "5.0", "organization_id" => organization.id})
                  ]
                )

                expect(second_result).to be_success
                expect(second_result.fees.count).to eq(1)
                expect(second_result.fees.first.presentation_breakdowns.map(&:presentation_by)).to match_array(
                  [{"region" => "eu"}, {"region" => "us"}]
                )
              end
            end

            it "returns fees from cache on subsequent calls" do
              first_result = charge_subscription_service.call
              second_result = charge_subscription_service.call

              expect(second_result).to be_success
              expect(second_result.fees.count).to eq(first_result.fees.count)
              expect(second_result.fees.first.units).to eq(first_result.fees.first.units)
              expect(second_result.fees.first.events_count).to eq(first_result.fees.first.events_count)
            end
          end

          context "with charge filters" do
            let(:region) { create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe usa]) }
            let(:europe_filter) { create(:charge_filter, charge:, properties: {amount: "20"}) }
            let(:usa_filter) { create(:charge_filter, charge:, properties: {amount: "50"}) }

            before do
              create(:charge_filter_value, charge_filter: europe_filter, billable_metric_filter: region, values: ["europe"])
              create(:charge_filter_value, charge_filter: usa_filter, billable_metric_filter: region, values: ["usa"])
            end

            context "when one filter has events and another does not" do
              before do
                create(
                  :event,
                  organization:,
                  subscription:,
                  code: billable_metric.code,
                  timestamp: Time.zone.parse("2022-03-16"),
                  properties: {region: "europe"}
                )
              end

              it "caches empty array for zero-usage filter and fee data for non-zero filter" do
                charge_subscription_service.call

                europe_cache_key = Subscriptions::ChargeCacheService.new(
                  subscription:, charge:, charge_filter: europe_filter
                ).cache_key
                europe_cached = JSON.parse(Rails.cache.read(europe_cache_key))
                expect(europe_cached.length).to eq(1)
                expect(europe_cached.first["events_count"]).to eq(1)

                usa_cache_key = Subscriptions::ChargeCacheService.new(
                  subscription:, charge:, charge_filter: usa_filter
                ).cache_key
                expect(Rails.cache.read(usa_cache_key)).to eq("[]")
              end

              it "returns consistent results on subsequent calls from cache" do
                first_result = charge_subscription_service.call
                second_result = charge_subscription_service.call

                expect(second_result.fees.count).to eq(first_result.fees.count)
                first_result.fees.zip(second_result.fees).each do |first_fee, second_fee|
                  expect(second_fee.units).to eq(first_fee.units)
                  expect(second_fee.events_count).to eq(first_fee.events_count)
                  expect(second_fee.amount_cents).to eq(first_fee.amount_cents)
                end
              end
            end
          end
        end
      end
    end

    context "when apply taxes" do
      let(:apply_taxes) { true }

      before do
        create(:tax, :applied_to_billing_entity, organization:, rate: 20)

        create(
          :event,
          organization: invoice.organization,
          subscription:,
          code: billable_metric.code,
          timestamp: boundaries.charges_to_datetime - 2.days
        )
      end

      it "creates a fee with applied taxes" do
        result = charge_subscription_service.call
        expect(result).to be_success
        expect(result.fees.first).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          charge_id: charge.id,
          amount_cents: 2000,
          precise_amount_cents: 2000.0,
          amount_currency: "EUR",
          units: 1,
          unit_amount_cents: 2000,
          precise_unit_amount: 20.0,
          events_count: 1,
          payment_status: "pending",

          taxes_rate: 20.0,
          taxes_amount_cents: 400,
          taxes_precise_amount_cents: 400.0
        )
        expect(result.fees.first.applied_taxes.count).to eq(1)
      end
    end

    context "with filtered_aggregations" do
      let(:filtered_aggregations) { [] }

      let(:region_filter) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[eu us asia])
      end

      let(:eu_charge_filter) { create(:charge_filter, charge:, properties: {amount: "20"}) }
      let(:us_charge_filter) { create(:charge_filter, charge:, properties: {amount: "30"}) }
      let(:asia_charge_filter) { create(:charge_filter, charge:, properties: {amount: "40"}) }

      before do
        create(:charge_filter_value, charge_filter: eu_charge_filter, billable_metric_filter: region_filter, values: ["eu"])
        create(:charge_filter_value, charge_filter: us_charge_filter, billable_metric_filter: region_filter, values: ["us"])
        create(:charge_filter_value, charge_filter: asia_charge_filter, billable_metric_filter: region_filter, values: ["asia"])

        # Events for each region
        create(
          :event,
          organization:,
          subscription:,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "eu"}
        )
        create(
          :event,
          organization:,
          subscription:,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "us"}
        )
        create(
          :event,
          organization:,
          subscription:,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {region: "asia"}
        )
        # Event without filter
        create(
          :event,
          organization:,
          subscription:,
          code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"),
          properties: {}
        )
      end

      context "when filtered_aggregations includes only specific filter IDs" do
        let(:filtered_aggregations) { [eu_charge_filter.id, us_charge_filter.id] }

        it "only aggregates events for the specified filters" do
          result = charge_subscription_service.call
          expect(result).to be_success

          eu_fee = result.fees.find { |f| f.charge_filter_id == eu_charge_filter.id }
          us_fee = result.fees.find { |f| f.charge_filter_id == us_charge_filter.id }
          asia_fee = result.fees.find { |f| f.charge_filter_id == asia_charge_filter.id }
          default_fee = result.fees.find { |f| f.charge_filter_id.nil? }

          expect(eu_fee).to have_attributes(units: 1, amount_cents: 2_000)
          expect(us_fee).to have_attributes(units: 1, amount_cents: 3_000)
          # Zero-amount fees are filtered out by default
          expect(asia_fee).to be_nil
          expect(default_fee).to be_nil
        end
      end

      context "when filtered_aggregations is an empty array" do
        let(:filtered_aggregations) { [] }

        it "bypasses aggregation for all filters and returns no fees" do
          result = charge_subscription_service.call
          expect(result).to be_success
          # All fees have zero amounts, so none are persisted
          expect(result.fees).to be_empty
        end
      end

      context "when filtered_aggregations includes nil for default bucket" do
        let(:filtered_aggregations) { [nil] }

        it "only aggregates events for the default bucket" do
          result = charge_subscription_service.call
          expect(result).to be_success

          default_fee = result.fees.find { |f| f.charge_filter_id.nil? }
          eu_fee = result.fees.find { |f| f.charge_filter_id == eu_charge_filter.id }

          expect(default_fee).to have_attributes(units: 1, amount_cents: 2_000)
          # Zero-amount fees are filtered out by default
          expect(eu_fee).to be_nil
        end
      end

      context "when filtered_aggregations is nil (default behavior)" do
        let(:filtered_aggregations) { nil }

        it "aggregates events for all filters" do
          result = charge_subscription_service.call
          expect(result).to be_success

          eu_fee = result.fees.find { |f| f.charge_filter_id == eu_charge_filter.id }
          us_fee = result.fees.find { |f| f.charge_filter_id == us_charge_filter.id }
          asia_fee = result.fees.find { |f| f.charge_filter_id == asia_charge_filter.id }
          default_fee = result.fees.find { |f| f.charge_filter_id.nil? }

          expect(eu_fee.units).to eq(1)
          expect(us_fee.units).to eq(1)
          expect(asia_fee.units).to eq(1)
          expect(default_fee.units).to eq(1)
        end
      end

      context "with recurring billable metric" do
        let(:billable_metric) { create(:weighted_sum_billable_metric, :recurring, organization:) }
        let(:filtered_aggregations) { [] }

        before do
          # Create events with proper value field for weighted_sum
          create(:event, organization:, subscription:, code: billable_metric.code,
            timestamp: Time.zone.parse("2022-03-16"), properties: {region: "eu", value: 10})
        end

        it "always aggregates regardless of filtered_aggregations" do
          result = charge_subscription_service.call
          expect(result).to be_success

          # Recurring metrics ignore the filtered_aggregations parameter, so fees should have data
          aggregated_fees = result.fees.select { |f| f.units != 0 || f.events_count != 0 }
          expect(aggregated_fees).not_to be_empty
        end
      end
    end

    context "with filter_by_group" do
      subject(:charge_subscription_service) do
        described_class.new(
          invoice:,
          charge:,
          subscription:,
          boundaries:,
          context: :current_usage,
          apply_taxes: false,
          filtered_aggregations: nil,
          usage_filters: UsageFilters.new(filter_by_group:)
        )
      end

      let(:billable_metric) do
        create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
      end

      let(:charge) do
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {amount: "20", pricing_group_keys: %w[region cloud]}
        )
      end

      let(:filter_by_group) { {"region" => ["eu"]} }

      before do
        create(:event, organization:, subscription:, code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"), properties: {region: "eu", cloud: "aws", value: 10})
        create(:event, organization:, subscription:, code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"), properties: {region: "eu", cloud: "gcp", value: 5})
        create(:event, organization:, subscription:, code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"), properties: {region: "us", cloud: "aws", value: 7})
      end

      it "filters by the specified group and keeps remaining group keys" do
        result = charge_subscription_service.call
        expect(result).to be_success

        # Only eu events, grouped by cloud (region removed from grouped_by)
        expect(result.fees.count).to eq(2)

        aws_fee = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
        expect(aws_fee).to have_attributes(units: 10)

        gcp_fee = result.fees.find { |f| f.grouped_by["cloud"] == "gcp" }
        expect(gcp_fee).to have_attributes(units: 5)
      end

      context "when filter_by_group is sent without array for values" do
        let(:filter_by_group) { {"region" => "eu"} }

        it "handles string values by converting them to array" do
          result = charge_subscription_service.call
          expect(result).to be_success

          # Only eu events, grouped by cloud (region removed from grouped_by)
          expect(result.fees.count).to eq(2)

          aws_fee = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
          expect(aws_fee).to have_attributes(units: 10)

          gcp_fee = result.fees.find { |f| f.grouped_by["cloud"] == "gcp" }
          expect(gcp_fee).to have_attributes(units: 5)
        end
      end

      context "when the charge also defines charge_filters" do
        let(:charge) do
          create(
            :standard_charge,
            plan: subscription.plan,
            billable_metric:,
            properties: {amount: "20", pricing_group_keys: %w[region cloud]}
          )
        end

        let(:region_filter) do
          create(:billable_metric_filter, billable_metric:, key: "region", values: %w[eu us])
        end

        let(:eu_filter) do
          create(
            :charge_filter,
            charge:,
            properties: {amount: "30", pricing_group_keys: %w[region cloud]}
          )
        end

        before do
          create(:charge_filter_value, charge_filter: eu_filter, billable_metric_filter: region_filter, values: ["eu"])
        end

        it "does not raise a FrozenError when merging filter_by_group into matching_filters" do
          expect { charge_subscription_service.call }.not_to raise_error
        end

        it "still produces a successful result" do
          result = charge_subscription_service.call
          expect(result).to be_success
        end
      end
    end

    context "with filter_by_presentation" do
      subject(:charge_subscription_service) do
        described_class.new(
          invoice:,
          charge:,
          subscription:,
          boundaries:,
          context: :current_usage,
          apply_taxes: false,
          filtered_aggregations: nil,
          usage_filters: UsageFilters.new(filter_by_presentation: filter_by_presentation)
        )
      end

      let(:charge) do
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: properties
        )
      end
      let(:properties) do
        {
          amount: "10",
          presentation_group_keys: presentation_group_keys
        }
      end
      let(:presentation_group_keys) { [{value: "department"}, {value: "region"}] }
      let(:filter_by_presentation) { nil }
      let(:aggregator) { instance_double("Aggregator") }
      let(:aggregation_result) { BaseService::Result.new }

      before do
        allow(BillableMetrics::AggregationFactory).to receive(:new_instance).and_call_original
      end

      it "calls aggregation factory with presentation_by containing all charge presentation keys" do
        charge_subscription_service.call

        expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
          hash_including(
            filters: hash_including(
              presentation_by: ["department", "region"]
            )
          )
        ).twice
      end

      context "when presentation_group_keys is empty" do
        let(:presentation_group_keys) { [] }

        it "calls aggregation factory without presentation_by" do
          charge_subscription_service.call

          expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
            hash_including(
              filters: hash_including(
                charge_id: charge.id
              )
            )
          ).twice
        end
      end

      context "when filter_by_presentation is empty" do
        let(:filter_by_presentation) { [] }

        it "calls aggregation factory with presentation_by as empty array" do
          charge_subscription_service.call

          expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
            hash_including(
              filters: hash_including(
                presentation_by: []
              )
            )
          ).twice
        end

        context "when presentation_group_keys is empty" do
          let(:presentation_group_keys) { [] }

          it "calls aggregation factory without presentation_by" do
            charge_subscription_service.call

            expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
              hash_including(
                filters: hash_including(
                  charge_id: charge.id
                )
              )
            ).twice
          end
        end
      end

      context "when filter_by_presentation values overlaps charge presentation keys" do
        let(:filter_by_presentation) { ["region"] }

        it "calls aggregation factory with presentation_by containing only overlapping keys" do
          charge_subscription_service.call

          expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
            hash_including(
              filters: hash_including(
                presentation_by: ["region"]
              )
            )
          ).twice
        end

        context "when presentation_group_keys is empty" do
          let(:presentation_group_keys) { [] }

          it "calls aggregation factory without presentation_by" do
            charge_subscription_service.call

            expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
              hash_including(
                filters: hash_including(
                  charge_id: charge.id
                )
              )
            ).twice
          end
        end
      end

      context "when filter_by_presentation values are not present in presention keys" do
        let(:filter_by_presentation) { ["other_name"] }

        it "calls aggregation factory with empty presentation keys" do
          charge_subscription_service.call

          expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
            hash_including(
              filters: hash_including(
                presentation_by: []
              )
            )
          ).twice
        end
      end
    end

    context "with skip_grouping" do
      subject(:charge_subscription_service) do
        described_class.new(
          invoice:,
          charge:,
          subscription:,
          boundaries:,
          context: :current_usage,
          apply_taxes: false,
          filtered_aggregations: nil,
          usage_filters: UsageFilters.new(skip_grouping: true)
        )
      end

      let(:billable_metric) do
        create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
      end

      let(:charge) do
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {amount: "20", pricing_group_keys: %w[cloud]}
        )
      end

      before do
        create(:event, organization:, subscription:, code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"), properties: {cloud: "aws", value: 10})
        create(:event, organization:, subscription:, code: billable_metric.code,
          timestamp: Time.zone.parse("2022-03-16"), properties: {cloud: "gcp", value: 5})
      end

      it "returns a single fee with all events aggregated without grouping" do
        result = charge_subscription_service.call
        expect(result).to be_success
        expect(result.fees.count).to eq(1)
        expect(result.fees.first).to have_attributes(
          units: 15,
          grouped_by: {}
        )
      end
    end
  end

  describe "presentation_breakdowns interaction with adjusted fees" do
    let(:billable_metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value")
    end
    let(:charge) do
      create(
        :standard_charge,
        plan: subscription.plan,
        billable_metric:,
        properties: {
          amount: "20",
          pricing_group_keys: ["cloud"],
          presentation_group_keys: [{value: "region"}]
        }
      )
    end

    let(:invoice) { create(:invoice, customer:, organization:, status: :draft) }

    before do
      create(
        :event, organization:, subscription:,
        code: billable_metric.code,
        timestamp: Time.zone.parse("2022-03-16"),
        properties: {cloud: "aws", value: 10, region: "eu"}
      )
      create(
        :event, organization:, subscription:,
        code: billable_metric.code,
        timestamp: Time.zone.parse("2022-03-16"),
        properties: {cloud: "aws", value: 5, region: "us"}
      )
      adjusted_fee
    end

    context "when the adjustment changes units" do
      let(:adjusted_fee) do
        create(
          :adjusted_fee,
          invoice:,
          subscription:,
          charge:,
          properties: {
            charges_from_datetime: boundaries.charges_from_datetime,
            charges_to_datetime: boundaries.charges_to_datetime
          },
          fee_type: :charge,
          adjusted_units: true,
          adjusted_amount: false,
          units: 3,
          grouped_by: {"cloud" => "aws"}
        )
      end

      it "does not build presentation_breakdowns on the fee replaced by an adjustment" do
        result = charge_subscription_service.call
        expect(result).to be_success

        aws_fee = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
        expect(aws_fee.units).to eq(3)
        expect(aws_fee.presentation_breakdowns).to be_empty
      end
    end

    context "when the adjustment keeps units the same" do
      let(:adjusted_fee) do
        create(
          :adjusted_fee,
          invoice:,
          subscription:,
          charge:,
          properties: {
            charges_from_datetime: boundaries.charges_from_datetime,
            charges_to_datetime: boundaries.charges_to_datetime
          },
          fee_type: :charge,
          adjusted_units: true,
          adjusted_amount: true,
          invoice_display_name: "renamed",
          units: 15,
          unit_amount_cents: 100,
          grouped_by: {"cloud" => "aws"}
        )
      end

      it "builds presentation_breakdowns from current events on the adjusted fee" do
        result = charge_subscription_service.call
        expect(result).to be_success

        aws_fee = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
        expect(aws_fee.presentation_breakdowns.map(&:presentation_by))
          .to match_array([{"region" => "eu"}, {"region" => "us"}])
        expect(aws_fee.presentation_breakdowns.map { |b| b.units.to_f })
          .to match_array([10.0, 5.0])
      end
    end

    context "when the adjustment only changes the display name" do
      let(:adjusted_fee) do
        create(
          :adjusted_fee,
          invoice:,
          subscription:,
          charge:,
          properties: {
            charges_from_datetime: boundaries.charges_from_datetime,
            charges_to_datetime: boundaries.charges_to_datetime
          },
          fee_type: :charge,
          adjusted_units: false,
          adjusted_amount: false,
          invoice_display_name: "renamed",
          grouped_by: {"cloud" => "aws"}
        )
      end

      it "builds presentation_breakdowns from current events on the adjusted fee" do
        result = charge_subscription_service.call
        expect(result).to be_success

        aws_fee = result.fees.find { |f| f.grouped_by["cloud"] == "aws" }
        expect(aws_fee.invoice_display_name).to eq("renamed")
        expect(aws_fee.presentation_breakdowns.map(&:presentation_by))
          .to match_array([{"region" => "eu"}, {"region" => "us"}])
        expect(aws_fee.presentation_breakdowns.map { |b| b.units.to_f })
          .to match_array([10.0, 5.0])
      end
    end
  end
end
