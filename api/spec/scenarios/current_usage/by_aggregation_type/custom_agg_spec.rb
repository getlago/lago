# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Aggregation - Custom Aggregation Scenarios", transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }

  let(:plan) { create(:plan, organization:, amount_cents: 0) }
  let(:billable_metric) { create(:custom_billable_metric, organization:, custom_aggregator:) }

  let(:custom_aggregator) do
    <<~RUBY
      def aggregate(event, previous_state, aggregation_properties)
        previous_units = previous_state[:total_units]
        event_units = BigDecimal(event.properties['value'] ? event.properties['value'] : 0) # 1
        certif = event.properties['certif']
        total_units = previous_units + event_units
        ranges = aggregation_properties['ranges']

        result_amount = ranges.reduce(0) do |amount, range|
          to = range['to']
          to = BigDecimal(to.to_s) if to

          # Range was already reached
          next amount if to && previous_units > to

          from = BigDecimal(range['from'].to_s)
          certif_amount = BigDecimal(range[certif] ? range[certif].to_s : '0')

          if !to || total_units <= to
            # Last matching range is reached
            units_to_use = if previous_units >= from
              # All new units are in the current range
              event_units
            else
              # Takes only the new units in the current range
              total_units - from + 1
            end
            break amount += certif_amount * units_to_use

          else
            # Range is not the last one
            units_to_use = if previous_units >= from
              # All remaining units in the range
              to - previous_units
            else
              # All units in the range
              to - from + 1
            end

            amount += certif_amount * units_to_use
          end

          amount
        end
        { total_units: total_units, amount: result_amount }
      end
    RUBY
  end

  let(:pay_in_advance) { false }

  context "with first aggregation scenario" do
    let(:standard_charge) do
      create(
        :standard_charge,
        billable_metric:,
        plan:,
        pay_in_advance:,
        properties: {
          amount: "2",
          custom_properties: {
            ranges: [
              {from: 0, to: 1_000, third_party: "0.15", first_party: "0.12"},
              {from: 1_001, to: 20_000, third_party: "0.12", first_party: "0.10"},
              {from: 20_001, to: 50_000, third_party: "0.10", first_party: "0.08"},
              {from: 50_001, to: nil, third_party: "0.08", first_party: "0.06"}
            ]
          }
        }
      )
    end

    let(:custom_charge) do
      create(
        :custom_charge,
        billable_metric:,
        plan:,
        pay_in_advance:,
        properties: {
          custom_properties: {
            ranges: [
              {from: 0, to: 1_000, third_party: "0.15", first_party: "0.12"},
              {from: 1_001, to: 20_000, third_party: "0.12", first_party: "0.10"},
              {from: 20_001, to: 50_000, third_party: "0.10", first_party: "0.08"},
              {from: 50_001, to: nil, third_party: "0.08", first_party: "0.06"}
            ]
          }
        }
      )
    end

    before do
      standard_charge
      custom_charge
    end

    context "when in arrears aggregation" do
      it "create fees for each charges" do
        travel_to(DateTime.new(2024, 2, 1)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        subscription = customer.subscriptions.first

        travel_to(DateTime.new(2024, 2, 6, 1)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 1,
                certif: "first_party"
              }
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(212)
          expect(json[:customer_usage][:charges_usage].count).to eq(2)

          standard_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "standard"
          end
          expect(standard_usage[:units]).to eq("1.0")
          expect(standard_usage[:amount_cents]).to eq(200)

          custom_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "custom"
          end
          expect(custom_usage[:units]).to eq("1.0")
          expect(custom_usage[:amount_cents]).to eq(12)
        end

        travel_to(DateTime.new(2024, 2, 6, 2)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 999,
                certif: "first_party"
              }
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(212_000)
          expect(json[:customer_usage][:charges_usage].count).to eq(2)

          standard_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "standard"
          end
          expect(standard_usage[:units]).to eq("1000.0")
          expect(standard_usage[:amount_cents]).to eq(200_000)

          custom_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "custom"
          end
          expect(custom_usage[:units]).to eq("1000.0")
          expect(custom_usage[:amount_cents]).to eq(12_000)
        end

        travel_to(DateTime.new(2024, 2, 6, 3)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 1,
                certif: "third_party"
              }
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(212_212)
          expect(json[:customer_usage][:charges_usage].count).to eq(2)

          standard_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "standard"
          end
          expect(standard_usage[:units]).to eq("1001.0")
          expect(standard_usage[:amount_cents]).to eq(200_200)

          custom_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "custom"
          end
          expect(custom_usage[:units]).to eq("1001.0")
          expect(custom_usage[:amount_cents]).to eq(12_012)
        end

        travel_to(DateTime.new(2024, 2, 6, 4)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 1,
                certif: "first_party"
              }
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(212_422)
          expect(json[:customer_usage][:charges_usage].count).to eq(2)

          standard_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "standard"
          end
          expect(standard_usage[:units]).to eq("1002.0")
          expect(standard_usage[:amount_cents]).to eq(200_400)

          custom_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "custom"
          end
          expect(custom_usage[:units]).to eq("1002.0")
          expect(custom_usage[:amount_cents]).to eq(12_022)
        end

        travel_to(DateTime.new(2024, 2, 6, 5)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 18998,
                certif: "first_party"
              }
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(4_202_002)
          expect(json[:customer_usage][:charges_usage].count).to eq(2)

          standard_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "standard"
          end
          expect(standard_usage[:units]).to eq("20000.0")
          expect(standard_usage[:amount_cents]).to eq(4_000_000)

          custom_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "custom"
          end
          expect(custom_usage[:units]).to eq("20000.0")
          expect(custom_usage[:amount_cents]).to eq(202_002)
        end

        travel_to(DateTime.new(2024, 2, 6, 6)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 1,
                certif: "first_party"
              }
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(4_202_210)
          expect(json[:customer_usage][:charges_usage].count).to eq(2)

          standard_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "standard"
          end
          expect(standard_usage[:units]).to eq("20001.0")
          expect(standard_usage[:amount_cents]).to eq(4_000_200)

          custom_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "custom"
          end
          expect(custom_usage[:units]).to eq("20001.0")
          expect(custom_usage[:amount_cents]).to eq(202_010)
        end

        travel_to(DateTime.new(2024, 2, 6, 7)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 30_002,
                certif: "first_party"
              }
            }
          )

          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(10_442_620)
          expect(json[:customer_usage][:charges_usage].count).to eq(2)

          standard_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "standard"
          end
          expect(standard_usage[:units]).to eq("50003.0")
          expect(standard_usage[:amount_cents]).to eq(10_000_600)

          custom_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "custom"
          end
          expect(custom_usage[:units]).to eq("50003.0")
          expect(custom_usage[:amount_cents]).to eq(442_020)
        end
      end

      context "when recurring aggregation" do
        let(:billable_metric) { create(:custom_billable_metric, organization:, custom_aggregator:, recurring: true) }

        it "create fees for each charges" do
          travel_to(DateTime.new(2024, 2, 1)) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              }
            )
          end

          subscription = customer.subscriptions.first

          travel_to(DateTime.new(2024, 2, 6, 1)) do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_customer_id: customer.external_id,
                external_subscription_id: subscription.external_id,
                properties: {
                  value: 1,
                  certif: "first_party"
                }
              }
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(212)
            expect(json[:customer_usage][:charges_usage].count).to eq(2)

            standard_usage = json[:customer_usage][:charges_usage].find do |cu|
              cu[:charge][:charge_model] == "standard"
            end
            expect(standard_usage[:units]).to eq("1.0")
            expect(standard_usage[:amount_cents]).to eq(200)

            custom_usage = json[:customer_usage][:charges_usage].find do |cu|
              cu[:charge][:charge_model] == "custom"
            end
            expect(custom_usage[:units]).to eq("1.0")
            expect(custom_usage[:amount_cents]).to eq(12)
          end

          travel_to(DateTime.new(2024, 2, 6, 2)) do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_customer_id: customer.external_id,
                external_subscription_id: subscription.external_id,
                properties: {
                  value: 10,
                  certif: "first_party"
                }
              }
            )

            fetch_current_usage(customer:)
            expect(json[:customer_usage][:total_amount_cents]).to eq(2_332)
            expect(json[:customer_usage][:charges_usage].count).to eq(2)

            standard_usage = json[:customer_usage][:charges_usage].find do |cu|
              cu[:charge][:charge_model] == "standard"
            end
            expect(standard_usage[:units]).to eq("11.0")
            expect(standard_usage[:amount_cents]).to eq(2_200)

            custom_usage = json[:customer_usage][:charges_usage].find do |cu|
              cu[:charge][:charge_model] == "custom"
            end
            expect(custom_usage[:units]).to eq("11.0")
            expect(custom_usage[:amount_cents]).to eq(132)
          end

          # Bill the subscription on it anniversary date
          travel_to(DateTime.new(2024, 3, 1)) do
            perform_billing

            expect(subscription.invoices.count).to eq(1)

            invoice = subscription.invoices.first
            expect(invoice.total_amount_cents).to eq(2_332)
            expect(invoice.fees.count).to eq(3)
          end

          # Send a new event after the billing
          travel_to(DateTime.new(2024, 3, 2)) do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_customer_id: customer.external_id,
                external_subscription_id: subscription.external_id,
                properties: {
                  value: 1000,
                  certif: "first_party"
                }
              }
            )

            fetch_current_usage(customer:)

            expect(json[:customer_usage][:total_amount_cents]).to eq(214_310)
            expect(json[:customer_usage][:charges_usage].count).to eq(2)

            standard_usage = json[:customer_usage][:charges_usage].find do |cu|
              cu[:charge][:charge_model] == "standard"
            end
            expect(standard_usage[:units]).to eq("1011.0")
            expect(standard_usage[:amount_cents]).to eq(202_200)

            custom_usage = json[:customer_usage][:charges_usage].find do |cu|
              cu[:charge][:charge_model] == "custom"
            end
            expect(custom_usage[:units]).to eq("1011.0")
            expect(custom_usage[:amount_cents]).to eq(12_110) # 1000 * 0.12 + 11 * 0.12
          end
        end
      end
    end

    context "when in advance aggregation" do
      let(:pay_in_advance) { true }

      it "creates a fee per events" do
        travel_to(DateTime.new(2024, 2, 1)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        subscription = customer.subscriptions.first

        travel_to(DateTime.new(2024, 2, 6, 1)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 1,
                certif: "first_party"
              }
            }
          )

          perform_all_enqueued_jobs

          expect(subscription.fees.count).to eq(2)
          expect(CachedAggregation.where(organization_id: organization.id).count).to eq(2)

          standard_fee = subscription.fees.find_by(charge: standard_charge)
          expect(standard_fee.amount_cents).to eq(200)
          expect(standard_fee.events_count).to eq(1)
          expect(standard_fee.units).to eq(1)

          custom_fee = subscription.fees.find_by(charge: custom_charge)
          expect(custom_fee.amount_cents).to eq(12)
          expect(custom_fee.events_count).to eq(1)
          expect(custom_fee.units).to eq(1)
        end

        travel_to(DateTime.new(2024, 2, 6, 2)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 10,
                certif: "first_party"
              }
            }
          )

          expect(subscription.fees.count).to eq(4)
          expect(CachedAggregation.where(organization_id: organization.id).count).to eq(4)

          standard_fee = subscription.fees.order(created_at: :desc).where(charge: standard_charge).first
          expect(standard_fee.amount_cents).to eq(2000)
          expect(standard_fee.events_count).to eq(1)
          expect(standard_fee.units).to eq(10)

          custom_fee = subscription.fees.order(created_at: :desc).where(charge: custom_charge).first
          expect(custom_fee.amount_cents).to eq(120) # 10 * 0.12
          expect(custom_fee.events_count).to eq(1)
          expect(custom_fee.units).to eq(10)
        end

        travel_to(DateTime.new(2024, 2, 6, 3)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_customer_id: customer.external_id,
              external_subscription_id: subscription.external_id,
              properties: {
                value: 1000,
                certif: "third_party"
              }
            }
          )

          expect(subscription.fees.count).to eq(6)
          expect(CachedAggregation.where(organization_id: organization.id).count).to eq(6)

          standard_fee = subscription.fees.order(created_at: :desc).where(charge: standard_charge).first
          expect(standard_fee.amount_cents).to eq(200_000)
          expect(standard_fee.events_count).to eq(1)
          expect(standard_fee.units).to eq(1000)

          custom_fee = subscription.fees.order(created_at: :desc).where(charge: custom_charge).first
          expect(custom_fee.amount_cents).to eq(14_967) # 989 * 0.15 + 11 * 0.12
          expect(custom_fee.events_count).to eq(1)
          expect(custom_fee.units).to eq(1000)
        end

        travel_to(DateTime.new(2024, 2, 6, 4)) do
          fetch_current_usage(customer:)
          expect(json[:customer_usage][:total_amount_cents]).to eq(217_299)
          expect(json[:customer_usage][:charges_usage].count).to eq(2)

          standard_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "standard"
          end
          expect(standard_usage[:units]).to eq("1011.0")
          expect(standard_usage[:amount_cents]).to eq(202_200)

          custom_usage = json[:customer_usage][:charges_usage].find do |cu|
            cu[:charge][:charge_model] == "custom"
          end
          expect(custom_usage[:units]).to eq("1011.0")
          expect(custom_usage[:amount_cents]).to eq(15_099) # 11 * 0.12 + 989 * 0.15 + 11 * 0.12
        end
      end
    end
  end

  context "with second aggregation scenario" do
    let(:pay_in_advance) { true }

    let(:custom_aggregator) do
      <<~RUBY
        def aggregate(event, previous_state, aggregation_properties)
          previous_units = previous_state[:total_units]

          ranges_property = aggregation_properties['ranges']
          amount_property = aggregation_properties['amount']
          rate_property = aggregation_properties['rate']
          min_amount_property = aggregation_properties['min_amount']
          fx_rate = BigDecimal(aggregation_properties['fx_rate'] ? aggregation_properties['fx_rate'].to_s : '1')
          event_value = BigDecimal(event.properties['value'].to_s)

          total_units = previous_units + 1
          result_amount = BigDecimal('0')

          if ranges_property != nil
            # The aggregation uses a range logic
            range = ranges_property.find { |r| BigDecimal(r['from'].to_s) <= total_units && (r['to'].nil? || total_units <= BigDecimal(r['to'].to_s)) }

            if range['amount'] != nil
              result_amount += BigDecimal(range['amount'].to_s)
            else
              result_amount += (event_value * BigDecimal(range['rate'].to_s) / 100) * fx_rate
            end
          elsif amount_property != nil
            # The aggregation uses an amount logic
            result_amount += BigDecimal(amount_property.to_s)

          elsif rate_property != nil
            min_amount = BigDecimal(min_amount_property.to_s)

            # The aggregation uses a rate logic
            amount = event_value * BigDecimal(rate_property.to_s) / 100
            amount = min_amount if amount < min_amount

            result_amount += amount
          end

          { total_units: total_units, amount: result_amount }
        end
      RUBY
    end

    let(:charge_filter_eur_inbound) do
    end

    let(:billable_metric_currency_filter) do
      create(:billable_metric_filter, billable_metric:, key: "currency", values: %w[gbp eur chf])
    end

    let(:billable_metric_direction_filter) do
      create(:billable_metric_filter, billable_metric:, key: "direction", values: %w[inbound outbound])
    end

    let(:billable_metric_scheme_filter) do
      create(:billable_metric_filter, billable_metric:, key: "scheme", values: %w[sepa swift bacs sic fps])
    end

    let(:charge) do
      create(
        :custom_charge,
        billable_metric:,
        plan:,
        pay_in_advance:,
        properties: {custom_properties: {}}
      )
    end

    let(:eur_sepa_filter) do
      create(
        :charge_filter,
        charge:,
        properties: {custom_properties: {amount: "1"}}
      )
    end

    let(:eur_swift_inbound_filter) do
      create(
        :charge_filter,
        charge:,
        properties: {custom_properties: {amount: "15"}}
      )
    end

    let(:eur_swift_outbound_filter) do
      create(
        :charge_filter,
        charge:,
        properties: {custom_properties: {amount: "25"}}
      )
    end

    let(:chf_filter) do
      create(
        :charge_filter,
        charge:,
        properties: {
          custom_properties: {
            ranges: [
              {from: 0, to: 10_000, rate: "0.4"},
              {from: 10_001, to: 15_000, rate: "0.3"},
              {from: 15_001, to: 22_000, rate: "0.25"},
              {from: 22_001, to: nil, rate: "0.2"}
            ],
            fx_rate: 0.88
          }
        }
      )
    end

    let(:gbp_swift_inbound_filter) do
      create(
        :charge_filter,
        charge:,
        properties: {custom_properties: {amount: "25"}}
      )
    end

    let(:gbp_swift_outbound_filter) do
      create(
        :charge_filter,
        charge:,
        properties: {custom_properties: {rate: "0.2", min_amount: "25"}}
      )
    end

    let(:gbp_domestic_fps_filter) do
      create(
        :charge_filter,
        charge:,
        properties: {
          custom_properties: {
            ranges: [
              {from: 0, to: 10_000, amount: "0.6"},
              {from: 10_001, to: 15_000, amount: "0.5"},
              {from: 15_001, to: 22_000, amount: "0.45"},
              {from: 22_001, to: nil, amount: "0.4"}
            ]
          }
        }
      )
    end

    let(:gbp_domestic_bacs_filter) do
      create(
        :charge_filter,
        charge:,
        properties: {
          custom_properties: {amount: "25"}
        }
      )
    end

    before do
      # EUR SEPA
      create(
        :charge_filter_value,
        charge_filter: eur_sepa_filter,
        billable_metric_filter: billable_metric_currency_filter,
        values: ["eur"]
      )
      create(
        :charge_filter_value,
        charge_filter: eur_sepa_filter,
        billable_metric_filter: billable_metric_scheme_filter,
        values: ["sepa"]
      )

      # EUR SWIFT inbound
      create(
        :charge_filter_value,
        charge_filter: eur_swift_inbound_filter,
        billable_metric_filter: billable_metric_currency_filter,
        values: ["eur"]
      )
      create(
        :charge_filter_value,
        charge_filter: eur_swift_inbound_filter,
        billable_metric_filter: billable_metric_scheme_filter,
        values: ["swift"]
      )
      create(
        :charge_filter_value,
        charge_filter: eur_swift_inbound_filter,
        billable_metric_filter: billable_metric_direction_filter,
        values: ["inbound"]
      )

      # EUR SWIFT outbound
      create(
        :charge_filter_value,
        charge_filter: eur_swift_outbound_filter,
        billable_metric_filter: billable_metric_currency_filter,
        values: ["eur"]
      )
      create(
        :charge_filter_value,
        charge_filter: eur_swift_outbound_filter,
        billable_metric_filter: billable_metric_scheme_filter,
        values: ["swift"]
      )
      create(
        :charge_filter_value,
        charge_filter: eur_swift_outbound_filter,
        billable_metric_filter: billable_metric_direction_filter,
        values: ["outbound"]
      )

      # CHF
      create(
        :charge_filter_value,
        charge_filter: chf_filter,
        billable_metric_filter: billable_metric_currency_filter,
        values: ["chf"]
      )

      # GBP Swift inbound
      create(
        :charge_filter_value,
        charge_filter: gbp_swift_inbound_filter,
        billable_metric_filter: billable_metric_currency_filter,
        values: ["gbp"]
      )
      create(
        :charge_filter_value,
        charge_filter: gbp_swift_inbound_filter,
        billable_metric_filter: billable_metric_scheme_filter,
        values: ["swift"]
      )
      create(
        :charge_filter_value,
        charge_filter: gbp_swift_inbound_filter,
        billable_metric_filter: billable_metric_direction_filter,
        values: ["inbound"]
      )

      # GBP Swift outbound
      create(
        :charge_filter_value,
        charge_filter: gbp_swift_outbound_filter,
        billable_metric_filter: billable_metric_currency_filter,
        values: ["gbp"]
      )
      create(
        :charge_filter_value,
        charge_filter: gbp_swift_outbound_filter,
        billable_metric_filter: billable_metric_scheme_filter,
        values: ["swift"]
      )
      create(
        :charge_filter_value,
        charge_filter: gbp_swift_outbound_filter,
        billable_metric_filter: billable_metric_direction_filter,
        values: ["outbound"]
      )

      # GBP Domestic FPS
      create(
        :charge_filter_value,
        charge_filter: gbp_domestic_fps_filter,
        billable_metric_filter: billable_metric_currency_filter,
        values: ["gbp"]
      )
      create(
        :charge_filter_value,
        charge_filter: gbp_domestic_fps_filter,
        billable_metric_filter: billable_metric_scheme_filter,
        values: ["fps"]
      )

      # GBP Domestic BACS
      create(
        :charge_filter_value,
        charge_filter: gbp_domestic_bacs_filter,
        billable_metric_filter: billable_metric_currency_filter,
        values: ["gbp"]
      )
      create(
        :charge_filter_value,
        charge_filter: gbp_domestic_bacs_filter,
        billable_metric_filter: billable_metric_scheme_filter,
        values: ["bacs"]
      )
    end

    it "create fees for each event" do
      travel_to(DateTime.new(2024, 2, 1)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first

      # GBP FPS inbound
      travel_to(DateTime.new(2024, 2, 6, 1)) do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_customer_id: customer.external_id,
            external_subscription_id: subscription.external_id,
            properties: {
              value: 10_000,
              direction: "inbound",
              scheme: "fps",
              currency: "gbp"
            }
          }
        )

        perform_all_enqueued_jobs

        expect(subscription.fees.count).to eq(1)
        expect(CachedAggregation.where(organization_id: organization.id).count).to eq(1)

        fee = subscription.fees.find_by(charge:)
        expect(fee.amount_cents).to eq(60)
        expect(fee.events_count).to eq(1)
        expect(fee.units).to eq(1)
      end

      travel_to(DateTime.new(2024, 2, 6, 3)) do
        create(
          :cached_aggregation,
          organization:,
          external_subscription_id: subscription.external_id,
          timestamp: DateTime.new(2024, 2, 6, 2),
          charge:,
          charge_filter: gbp_domestic_fps_filter,
          current_aggregation: 10_000,
          max_aggregation: 10_000,
          current_amount: 600_000
        )

        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_customer_id: customer.external_id,
            external_subscription_id: subscription.external_id,
            properties: {
              value: 10_000,
              direction: "outbound",
              scheme: "fps",
              currency: "gbp"
            }
          }
        )

        perform_all_enqueued_jobs

        expect(subscription.fees.count).to eq(2)
        expect(CachedAggregation.where(organization_id: organization.id).count).to eq(3)

        fee = subscription.fees.where(charge:).order(created_at: :desc).first
        expect(fee.amount_cents).to eq(50)
        expect(fee.events_count).to eq(1)
        expect(fee.units).to eq(1)
      end

      # GBP BACS inbound
      travel_to(DateTime.new(2024, 2, 6, 4)) do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_customer_id: customer.external_id,
            external_subscription_id: subscription.external_id,
            properties: {
              value: 2_000_000,
              direction: "intbound",
              scheme: "bacs",
              currency: "gbp"
            }
          }
        )

        perform_all_enqueued_jobs

        expect(subscription.fees.count).to eq(3)
        expect(CachedAggregation.where(organization_id: organization.id).count).to eq(4)

        fee = subscription.fees.where(charge:).order(created_at: :desc).first
        expect(fee.amount_cents).to eq(2500)
        expect(fee.events_count).to eq(1)
        expect(fee.units).to eq(1)
      end

      # GBP SWIFT
      travel_to(DateTime.new(2024, 2, 6, 5)) do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_customer_id: customer.external_id,
            external_subscription_id: subscription.external_id,
            properties: {
              value: 10_000,
              direction: "outbound",
              scheme: "swift",
              currency: "gbp"
            }
          }
        )

        perform_all_enqueued_jobs

        expect(subscription.fees.count).to eq(4)
        expect(CachedAggregation.where(organization_id: organization.id).count).to eq(5)

        fee = subscription.fees.where(charge:).order(created_at: :desc).first
        expect(fee.amount_cents).to eq(2_500)
        expect(fee.events_count).to eq(1)
        expect(fee.units).to eq(1)
      end

      travel_to(DateTime.new(2024, 2, 6, 5, 1)) do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_customer_id: customer.external_id,
            external_subscription_id: subscription.external_id,
            properties: {
              value: 100_000,
              direction: "outbound",
              scheme: "swift",
              currency: "gbp"
            }
          }
        )

        perform_all_enqueued_jobs

        expect(subscription.fees.count).to eq(5)
        expect(CachedAggregation.where(organization_id: organization.id).count).to eq(6)

        fee = subscription.fees.where(charge:).order(created_at: :desc).first
        expect(fee.amount_cents).to eq(20_000)
        expect(fee.events_count).to eq(1)
        expect(fee.units).to eq(1)
      end

      # SEPA EUR
      travel_to(DateTime.new(2024, 2, 6, 6)) do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_customer_id: customer.external_id,
            external_subscription_id: subscription.external_id,
            properties: {
              value: 10_000,
              direction: "outbound",
              scheme: "sepa",
              currency: "eur"
            }
          }
        )

        perform_all_enqueued_jobs

        expect(subscription.fees.count).to eq(6)
        expect(CachedAggregation.where(organization_id: organization.id).count).to eq(7)

        fee = subscription.fees.where(charge:).order(created_at: :desc).first
        expect(fee.amount_cents).to eq(100)
        expect(fee.events_count).to eq(1)
        expect(fee.units).to eq(1)
      end

      # CHF
      travel_to(DateTime.new(2024, 2, 6, 7)) do
        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_customer_id: customer.external_id,
            external_subscription_id: subscription.external_id,
            properties: {
              value: 100_000,
              direction: "outbound",
              scheme: "sic",
              currency: "chf"
            }
          }
        )

        perform_all_enqueued_jobs

        expect(subscription.fees.count).to eq(7)
        expect(CachedAggregation.where(organization_id: organization.id).count).to eq(8)

        fee = subscription.fees.where(charge:).order(created_at: :desc).first
        expect(fee.amount_cents).to eq(35_200)
        expect(fee.events_count).to eq(1)
        expect(fee.units).to eq(1)
      end

      travel_to(DateTime.new(2024, 2, 6, 9)) do
        create(
          :cached_aggregation,
          organization:,
          external_subscription_id: subscription.external_id,
          timestamp: DateTime.new(2024, 2, 6, 8),
          charge:,
          charge_filter: chf_filter,
          current_aggregation: 10_000,
          max_aggregation: 10_000,
          current_amount: 600_000
        )

        create_event(
          {
            code: billable_metric.code,
            transaction_id: SecureRandom.uuid,
            external_customer_id: customer.external_id,
            external_subscription_id: subscription.external_id,
            properties: {
              value: 1000,
              direction: "outbound",
              scheme: "sic",
              currency: "chf"
            }
          }
        )

        perform_all_enqueued_jobs

        expect(subscription.fees.count).to eq(8)
        expect(CachedAggregation.where(organization_id: organization.id).count).to eq(10)

        fee = subscription.fees.where(charge:).order(created_at: :desc).first
        expect(fee.amount_cents).to eq(264)
        expect(fee.events_count).to eq(1)
        expect(fee.units).to eq(1)
      end

      # Fetch current usage to make sure the aggregation is correct
      travel_to(DateTime.new(2024, 2, 6, 10)) do
        fetch_current_usage(customer:)

        expect(json[:customer_usage][:total_amount_cents]).to eq(60_772)
        expect(json[:customer_usage][:charges_usage].count).to eq(1)

        charge_usage = json[:customer_usage][:charges_usage].first
        expect(charge_usage[:units]).to eq("8.0")
        expect(charge_usage[:events_count]).to eq(8)
        expect(charge_usage[:amount_cents]).to eq(60_772)
        expect(charge_usage[:filters].count).to eq(9)

        gbp_domestic_fps_charge = charge_usage[:filters].find do |f|
          f[:values] == gbp_domestic_fps_filter.to_h.symbolize_keys
        end
        expect(gbp_domestic_fps_charge[:events_count]).to eq(2)
        expect(gbp_domestic_fps_charge[:units]).to eq("2.0")
        expect(gbp_domestic_fps_charge[:amount_cents]).to eq(120)

        gbp_domestic_bacs_charge = charge_usage[:filters].find do |f|
          f[:values] == gbp_domestic_bacs_filter.to_h.symbolize_keys
        end
        expect(gbp_domestic_bacs_charge[:events_count]).to eq(1)
        expect(gbp_domestic_bacs_charge[:units]).to eq("1.0")
        expect(gbp_domestic_bacs_charge[:amount_cents]).to eq(2500)

        gbp_swift_outbound_charge = charge_usage[:filters].find do |f|
          f[:values] == gbp_swift_outbound_filter.to_h.symbolize_keys
        end
        expect(gbp_swift_outbound_charge[:events_count]).to eq(2)
        expect(gbp_swift_outbound_charge[:units]).to eq("2.0")
        expect(gbp_swift_outbound_charge[:amount_cents]).to eq(22_500)

        eur_sepa_charge = charge_usage[:filters].find do |f|
          f[:values] == eur_sepa_filter.to_h.symbolize_keys
        end
        expect(eur_sepa_charge[:events_count]).to eq(1)
        expect(eur_sepa_charge[:units]).to eq("1.0")
        expect(eur_sepa_charge[:amount_cents]).to eq(100)

        eur_swift_inbound_charge = charge_usage[:filters].find do |f|
          f[:values] == eur_swift_inbound_filter.to_h.symbolize_keys
        end
        expect(eur_swift_inbound_charge[:events_count]).to eq(0)
        expect(eur_swift_inbound_charge[:units]).to eq("0.0")
        expect(eur_swift_inbound_charge[:amount_cents]).to eq(0)

        eur_swift_outbound_charge = charge_usage[:filters].find do |f|
          f[:values] == eur_swift_outbound_filter.to_h.symbolize_keys
        end
        expect(eur_swift_outbound_charge[:events_count]).to eq(0)
        expect(eur_swift_outbound_charge[:units]).to eq("0.0")
        expect(eur_swift_outbound_charge[:amount_cents]).to eq(0)

        chf_charge = charge_usage[:filters].find do |f|
          f[:values] == chf_filter.to_h.symbolize_keys
        end
        expect(chf_charge[:events_count]).to eq(2)
        expect(chf_charge[:units]).to eq("2.0")
        expect(chf_charge[:amount_cents]).to eq(35_552)
      end
    end
  end
end
