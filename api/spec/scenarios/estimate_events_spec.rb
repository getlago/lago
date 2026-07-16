# frozen_string_literal: true

require "rails_helper"

describe "Estimate In Advance Events" do
  [
    :postgres,
    :clickhouse
  ].each do |store|
    context "with #{store} store", clickhouse: store == :clickhouse do
      let(:organization) { create(:organization, webhook_url: nil, clickhouse_events_store: store == :clickhouse) }
      let(:customer) { create(:customer, organization: organization) }
      let(:plan) { create(:plan, organization:, amount_cents: 1000) }

      let(:metric) { create(:billable_metric, organization:) }
      let(:charge) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: true,
          properties: {amount: "10"}
        )
      end

      before { charge }

      context "with a count aggregation" do
        it "returns the estimated price of the events, taking care of the existing ones" do
          travel_to(Time.zone.parse("2025-09-01")) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            })
          end

          subscription = customer.subscriptions.last

          # Estimate event without existing events
          travel_to(Time.zone.parse("2025-09-02")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(1000)
            expect(fee["units"]).to eq("1.0")
            expect(fee["events_count"]).to eq(1)
          end

          # Create an event
          travel_to(Time.zone.parse("2025-09-03")) do
            create_event({
              transaction_id: SecureRandom.uuid,
              code: metric.code,
              external_subscription_id: subscription.external_id
            })
          end

          # Estimate a new event with an existing one
          travel_to(Time.zone.parse("2025-09-04")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(1000)
            expect(fee["units"]).to eq("1.0")
            expect(fee["events_count"]).to eq(1)
          end
        end
      end

      context "with a sum aggregation" do
        let(:metric) { create(:sum_billable_metric, organization:) }

        it "returns the estimated price of the events, taking care of the existing ones" do
          travel_to(Time.zone.parse("2025-09-01")) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            })
          end

          subscription = customer.subscriptions.last

          # Estimate event without existing events
          travel_to(Time.zone.parse("2025-09-02")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => 4}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(4000)
            expect(fee["units"]).to eq("4.0")
            expect(fee["events_count"]).to eq(1)
          end

          # Create an event
          travel_to(Time.zone.parse("2025-09-03")) do
            create_event({
              transaction_id: SecureRandom.uuid,
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => 4}
            })
          end

          # Estimate a new event with an existing one
          travel_to(Time.zone.parse("2025-09-04")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => 4}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(4000)
            expect(fee["units"]).to eq("4.0")
            expect(fee["events_count"]).to eq(1)
          end
        end

        context "when billable metric is recurring" do
          let(:metric) { create(:sum_billable_metric, :recurring, organization:) }

          it "returns the estimated price of the events, taking care of the existing ones" do
            travel_to(Time.zone.parse("2024-09-01")) do
              create_subscription({
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              })
            end

            subscription = customer.subscriptions.last

            # Create an event
            travel_to(Time.zone.parse("2024-09-03")) do
              create_event({
                transaction_id: SecureRandom.uuid,
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 4}
              })
            end

            # Estimate event without existing events
            travel_to(Time.zone.parse("2025-09-02")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 4}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(4000)
              expect(fee["units"]).to eq("4.0")
              expect(fee["events_count"]).to eq(1)
            end

            # Create an event
            travel_to(Time.zone.parse("2025-09-03")) do
              create_event({
                transaction_id: SecureRandom.uuid,
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 4}
              })
            end

            # Estimate a new event with an existing one
            travel_to(Time.zone.parse("2025-09-04")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 4}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(4000)
              expect(fee["units"]).to eq("4.0")
              expect(fee["events_count"]).to eq(1)
            end
          end
        end

        context "when charge model is dynamic" do
          let(:charge) do
            create(
              :dynamic_charge,
              plan:,
              billable_metric: metric,
              pay_in_advance: true
            )
          end

          it "returns the estimated price of the events, taking care of the existing ones" do
            travel_to(Time.zone.parse("2025-09-01")) do
              create_subscription({
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              })
            end

            subscription = customer.subscriptions.last

            # Estimate event without existing events
            travel_to(Time.zone.parse("2025-09-02")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 1},
                precise_total_amount_cents: 200
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(200)
              expect(fee["units"]).to eq("1.0")
              expect(fee["events_count"]).to eq(1)
            end

            # Create an event
            travel_to(Time.zone.parse("2025-09-03")) do
              create_event({
                transaction_id: SecureRandom.uuid,
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 1},
                precise_total_amount_cents: 200
              })
            end

            # Estimate a new event with an existing one
            travel_to(Time.zone.parse("2025-09-04")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 1},
                precise_total_amount_cents: 200
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(200)
              expect(fee["units"]).to eq("1.0")
              expect(fee["events_count"]).to eq(1)
            end
          end
        end

        context "when charge model is percentage", :premium do
          let(:charge) do
            create(
              :percentage_charge,
              plan:,
              billable_metric: metric,
              pay_in_advance: true,
              properties: {rate: "0.5", per_transaction_min_amount: "12"}
            )
          end

          it "returns the estimated price of the events, taking care of the existing ones" do
            travel_to(Time.zone.parse("2025-09-01")) do
              create_subscription({
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              })
            end

            subscription = customer.subscriptions.last

            # Estimate event without existing events
            travel_to(Time.zone.parse("2025-09-02")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 4}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(1200)
              expect(fee["units"]).to eq("4.0")
              expect(fee["events_count"]).to eq(1)
            end

            # Create an event
            travel_to(Time.zone.parse("2025-09-03")) do
              create_event({
                transaction_id: SecureRandom.uuid,
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 4}
              })
            end

            # Estimate a new event with an existing one
            travel_to(Time.zone.parse("2025-09-04")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => 20_000}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(10_000)
              expect(fee["units"]).to eq("20000.0")
              expect(fee["events_count"]).to eq(1)
            end
          end

          context "when billable metric is recurring" do
            let(:metric) { create(:sum_billable_metric, :recurring, organization:) }

            it "returns the estimated price of the events, taking care of the existing ones" do
              travel_to(Time.zone.parse("2024-09-01")) do
                create_subscription({
                  external_customer_id: customer.external_id,
                  external_id: customer.external_id,
                  plan_code: plan.code
                })
              end

              subscription = customer.subscriptions.last

              # Create an event
              travel_to(Time.zone.parse("2024-09-03")) do
                create_event({
                  transaction_id: SecureRandom.uuid,
                  code: metric.code,
                  external_subscription_id: subscription.external_id,
                  properties: {metric.field_name => 4}
                })
              end

              # Estimate event without existing events
              travel_to(Time.zone.parse("2025-09-02")) do
                result = estimate_event({
                  code: metric.code,
                  external_subscription_id: subscription.external_id,
                  properties: {metric.field_name => 4}
                })

                fee = result[:fees].first
                expect(fee["amount_cents"]).to eq(1200)
                expect(fee["units"]).to eq("4.0")
                expect(fee["events_count"]).to eq(1)
              end

              # Create an event
              travel_to(Time.zone.parse("2025-09-03")) do
                create_event({
                  transaction_id: SecureRandom.uuid,
                  code: metric.code,
                  external_subscription_id: subscription.external_id,
                  properties: {metric.field_name => 4}
                })
              end

              # Estimate a new event with an existing one
              travel_to(Time.zone.parse("2025-09-04")) do
                result = estimate_event({
                  code: metric.code,
                  external_subscription_id: subscription.external_id,
                  properties: {metric.field_name => 20_000}
                })

                fee = result[:fees].first
                expect(fee["amount_cents"]).to eq(10_000)
                expect(fee["units"]).to eq("20000.0")
                expect(fee["events_count"]).to eq(1)
              end
            end
          end

          context "with free units" do
            let(:charge) do
              create(
                :percentage_charge,
                plan:,
                billable_metric: metric,
                pay_in_advance: true,
                properties: {rate: "50", free_units_per_events: 1}
              )
            end

            it "returns the estimated price of the events, taking care of the existing ones" do
              travel_to(Time.zone.parse("2025-09-01")) do
                create_subscription({
                  external_customer_id: customer.external_id,
                  external_id: customer.external_id,
                  plan_code: plan.code
                })
              end

              subscription = customer.subscriptions.last

              # Estimate event without existing events
              travel_to(Time.zone.parse("2025-09-02")) do
                result = estimate_event({
                  code: metric.code,
                  external_subscription_id: subscription.external_id,
                  properties: {metric.field_name => 4}
                })

                fee = result[:fees].first
                expect(fee["amount_cents"]).to eq(0)
                expect(fee["units"]).to eq("4.0")
                expect(fee["events_count"]).to eq(1)
              end

              # Create an event
              travel_to(Time.zone.parse("2025-09-03")) do
                create_event({
                  transaction_id: SecureRandom.uuid,
                  code: metric.code,
                  external_subscription_id: subscription.external_id,
                  properties: {metric.field_name => 4}
                })
              end

              # Estimate a new event with an existing one
              travel_to(Time.zone.parse("2025-09-04")) do
                result = estimate_event({
                  code: metric.code,
                  external_subscription_id: subscription.external_id,
                  properties: {metric.field_name => 4}
                })

                fee = result[:fees].first
                expect(fee["amount_cents"]).to eq(200)
                expect(fee["units"]).to eq("4.0")
                expect(fee["events_count"]).to eq(1)
              end
            end
          end
        end
      end

      context "with a prorated sum aggregation" do
        let(:metric) { create(:sum_billable_metric, :recurring, organization:) }
        let(:charge) do
          create(
            :standard_charge,
            plan:,
            billable_metric: metric,
            pay_in_advance: true,
            properties: {amount: "10"},
            prorated: true
          )
        end

        it "returns the estimated price of the events, taking care of the existing ones" do
          travel_to(Time.zone.parse("2025-09-01")) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            })
          end

          subscription = customer.subscriptions.last

          # Estimate event without existing events
          travel_to(Time.zone.parse("2025-09-02")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => 4}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(3867)
            expect(fee["units"]).to eq("4.0")
            expect(fee["events_count"]).to eq(1)
          end

          # Create an event
          travel_to(Time.zone.parse("2025-09-03")) do
            create_event({
              transaction_id: SecureRandom.uuid,
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => 4}
            })
          end

          # Estimate a new event with an existing one
          travel_to(Time.zone.parse("2025-09-04")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => 4}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(3600)
            expect(fee["units"]).to eq("4.0")
            expect(fee["events_count"]).to eq(1)
          end
        end
      end

      context "with a unique_count aggregation" do
        let(:metric) { create(:unique_count_billable_metric, organization:) }

        it "returns the estimated price of the events, taking care of the existing ones" do
          travel_to(Time.zone.parse("2025-09-01")) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            })
          end

          subscription = customer.subscriptions.last

          # Estimate event without existing events
          travel_to(Time.zone.parse("2025-09-02")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "1234"}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(1000)
            expect(fee["units"]).to eq("1.0")
            expect(fee["events_count"]).to eq(1)
          end

          # Create an event
          travel_to(Time.zone.parse("2025-09-03")) do
            create_event({
              transaction_id: SecureRandom.uuid,
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "1234"}
            })
          end

          # Estimate a new event with an existing one
          travel_to(Time.zone.parse("2025-09-04")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "1234"}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(0)
            expect(fee["units"]).to eq("0.0")
            expect(fee["events_count"]).to eq(1)
          end

          travel_to(Time.zone.parse("2025-09-05")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "5678"}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(1000)
            expect(fee["units"]).to eq("1.0")
            expect(fee["events_count"]).to eq(1)
          end

          travel_to(Time.zone.parse("2025-09-05")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "1234", :operation_type => "remove"}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(0)
            expect(fee["units"]).to eq("0.0")
            expect(fee["events_count"]).to eq(1)
          end
        end

        context "when billable metric is recurring" do
          let(:metric) { create(:unique_count_billable_metric, :recurring, organization:) }

          it "returns the estimated price of the events, taking care of the existing ones" do
            travel_to(Time.zone.parse("2024-09-01")) do
              create_subscription({
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code
              })
            end

            subscription = customer.subscriptions.last

            # Create an event
            travel_to(Time.zone.parse("2024-09-03")) do
              create_event({
                transaction_id: SecureRandom.uuid,
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => "1234"}
              })
            end

            # Estimate event with a pre-existing one
            travel_to(Time.zone.parse("2025-09-02")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => "1234"}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(0)
              expect(fee["units"]).to eq("0.0")
              expect(fee["events_count"]).to eq(1)
            end

            # Estimate event without a pre-existing one
            travel_to(Time.zone.parse("2025-09-02")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => "9876"}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(1000)
              expect(fee["units"]).to eq("1.0")
              expect(fee["events_count"]).to eq(1)
            end

            # Create an event
            travel_to(Time.zone.parse("2025-09-03")) do
              create_event({
                transaction_id: SecureRandom.uuid,
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => "1234"}
              })
            end

            # Estimate a new event with an existing one
            travel_to(Time.zone.parse("2025-09-04")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => "1234"}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(0)
              expect(fee["units"]).to eq("0.0")
              expect(fee["events_count"]).to eq(1)
            end

            travel_to(Time.zone.parse("2025-09-05")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => "5678"}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(1000)
              expect(fee["units"]).to eq("1.0")
              expect(fee["events_count"]).to eq(1)
            end

            travel_to(Time.zone.parse("2025-09-05")) do
              result = estimate_event({
                code: metric.code,
                external_subscription_id: subscription.external_id,
                properties: {metric.field_name => "1234", :operation_type => "remove"}
              })

              fee = result[:fees].first
              expect(fee["amount_cents"]).to eq(0)
              expect(fee["units"]).to eq("0.0")
              expect(fee["events_count"]).to eq(1)
            end
          end
        end
      end

      context "with a prorated unique_count aggregation" do
        let(:metric) { create(:unique_count_billable_metric, :recurring, organization:) }
        let(:charge) do
          create(
            :standard_charge,
            plan:,
            billable_metric: metric,
            pay_in_advance: true,
            properties: {amount: "10"},
            prorated: true
          )
        end

        it "returns the estimated price of the events, taking care of the existing ones" do
          travel_to(Time.zone.parse("2025-09-01")) do
            create_subscription({
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            })
          end

          subscription = customer.subscriptions.last

          # Estimate event without existing events
          travel_to(Time.zone.parse("2025-09-02")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "1234"}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(967)
            expect(fee["units"]).to eq("1.0")
            expect(fee["events_count"]).to eq(1)
          end

          # Create an event
          travel_to(Time.zone.parse("2025-09-03")) do
            create_event({
              transaction_id: SecureRandom.uuid,
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "1234"}
            })
          end

          # Estimate a new event with an existing one
          travel_to(Time.zone.parse("2025-09-04")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "1234"}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(0)
            expect(fee["units"]).to eq("0.0")
            expect(fee["events_count"]).to eq(1)
          end

          travel_to(Time.zone.parse("2025-09-05")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "5678"}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(867)
            expect(fee["units"]).to eq("1.0")
            expect(fee["events_count"]).to eq(1)
          end

          travel_to(Time.zone.parse("2025-09-05")) do
            result = estimate_event({
              code: metric.code,
              external_subscription_id: subscription.external_id,
              properties: {metric.field_name => "1234", :operation_type => "remove"}
            })

            fee = result[:fees].first
            expect(fee["amount_cents"]).to eq(0)
            expect(fee["units"]).to eq("0.0")
            expect(fee["events_count"]).to eq(1)
          end
        end
      end
    end
  end
end
