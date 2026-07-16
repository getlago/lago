# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::SubscriptionService do
  subject(:fees_subscription_service) do
    described_class.new(
      invoice:,
      subscription:,
      boundaries:,
      context:
    )
  end

  let(:billing_entity) { create(:billing_entity) }
  let(:organization) { billing_entity.organization }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, organization:, rate: 20) }
  let(:started_at) { Time.zone.parse("2022-01-01 00:01") }
  let(:created_at) { started_at }
  let(:subscription_at) { started_at }
  let(:context) { nil }

  let(:plan) do
    create(
      :plan,
      organization:,
      amount_cents: 100,
      amount_currency: "EUR"
    )
  end
  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:boundaries) do
    BillingPeriodBoundaries.new(
      from_datetime: Time.zone.parse("2022-03-01 00:00:00"),
      to_datetime: Time.zone.parse("2022-03-31 23:59:59"),
      charges_from_datetime: Time.zone.parse("2022-03-01 00:00:00"),
      charges_to_datetime: Time.zone.parse("2022-03-31 23:59:59"),
      charges_duration: 31.days,
      timestamp: Time.zone.parse("2022-04-02 00:00").end_of_month.to_i
    )
  end

  let(:subscription) do
    create(
      :subscription,
      plan:,
      started_at:,
      subscription_at:,
      customer:,
      created_at:,
      external_id: "sub_id"
    )
  end

  before { tax }

  context "when invoice is on a full period" do
    it "creates a fee" do
      result = fees_subscription_service.call

      expect(result.fee).to have_attributes(
        id: String,
        organization_id: organization.id,
        billing_entity_id: billing_entity.id,
        invoice_id: invoice.id,
        amount_cents: 100,
        precise_amount_cents: 100.0,
        amount_currency: "EUR",
        units: 1,
        events_count: nil,
        payment_status: "pending",
        unit_amount_cents: 100,
        precise_unit_amount: 1,
        amount_details: {"plan_amount_cents" => 100}
      )
    end

    it "persists fee" do
      expect { fees_subscription_service.call }.to change(Fee, :count).by(1)
    end

    context "with preview context" do
      let(:context) { :preview }

      it "does not persist fee" do
        expect { fees_subscription_service.call }.not_to change(Fee, :count)
      end
    end

    context "when plan has a trial period" do
      before do
        plan.update(trial_period: trial_duration)
        subscription.update(started_at: boundaries.from_datetime)
      end

      context "when trial end in period" do
        let(:trial_duration) { 3 }

        it "creates a fee with prorated amount based on trial" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            amount_cents: 90,
            precise_amount_cents: 90.32258064516128,
            unit_amount_cents: 90,
            precise_unit_amount: 0.9,
            amount_details: {"plan_amount_cents" => 100}
          )
        end
      end

      context "when trial ends after end of period" do
        let(:trial_duration) { 45 }

        it "creates a fee with zero amount" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            amount_cents: 0,
            precise_amount_cents: 0.0
          )
        end
      end
    end

    context "when there is adjusted fee" do
      let(:adjusted_fee) do
        create(
          :adjusted_fee,
          invoice:,
          subscription:,
          properties:,
          adjusted_units: true,
          adjusted_amount: false,
          units: 3
        )
      end
      let(:properties) do
        {
          from_datetime: boundaries.from_datetime,
          to_datetime: boundaries.to_datetime
        }
      end

      before do
        adjusted_fee
        invoice.draft!
      end

      context "with adjusted units" do
        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 300,
            precise_amount_cents: 300.0,
            amount_currency: "EUR",
            units: 3,
            events_count: nil,
            payment_status: "pending",
            unit_amount_cents: 100,
            precise_unit_amount: 1
          )
        end
      end

      context "with adjusted amount" do
        let(:adjusted_fee) do
          create(
            :adjusted_fee,
            invoice:,
            subscription:,
            properties:,
            adjusted_units: false,
            adjusted_amount: true,
            units: 3,
            unit_amount_cents: 200,
            unit_precise_amount_cents: 200.0
          )
        end

        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 600,
            precise_amount_cents: 600.0,
            amount_currency: "EUR",
            units: 3,
            events_count: nil,
            payment_status: "pending",
            unit_amount_cents: 200,
            precise_unit_amount: 2
          )
        end

        context "when precise unit amounts are used" do
          let(:adjusted_fee) do
            create(
              :adjusted_fee,
              invoice:,
              subscription:,
              properties:,
              adjusted_units: false,
              adjusted_amount: true,
              units: 1000,
              unit_amount_cents: 0,
              unit_precise_amount_cents: 0.1
            )
          end

          it "creates a fee" do
            result = fees_subscription_service.call

            expect(result.fee).to have_attributes(
              id: String,
              invoice_id: invoice.id,
              amount_cents: 100,
              precise_amount_cents: 100.0,
              amount_currency: "EUR",
              units: 1000,
              events_count: nil,
              payment_status: "pending",
              unit_amount_cents: 0,
              precise_unit_amount: 0.001
            )
          end
        end
      end

      context "with adjusted display name" do
        let(:adjusted_fee) do
          create(
            :adjusted_fee,
            invoice:,
            subscription:,
            properties:,
            adjusted_units: false,
            adjusted_amount: false,
            units: 1,
            invoice_display_name: "test123"
          )
        end

        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 100,
            precise_amount_cents: 100.0,
            amount_currency: "EUR",
            units: 1,
            events_count: nil,
            payment_status: "pending",
            unit_amount_cents: 100,
            precise_unit_amount: 1,
            invoice_display_name: "test123"
          )
        end
      end

      context "with invoice NOT in draft status" do
        before { invoice.finalized! }

        it "creates a fee without using adjusted fee attributes" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 100,
            precise_amount_cents: 100.0,
            amount_currency: "EUR",
            units: 1,
            events_count: nil,
            payment_status: "pending",
            unit_amount_cents: 100,
            precise_unit_amount: 1
          )
        end
      end
    end
  end

  context "when subscription has never been billed" do
    let(:boundaries) do
      BillingPeriodBoundaries.new(
        from_datetime: subscription.started_at.beginning_of_day,
        to_datetime: subscription.started_at.end_of_month.end_of_day,
        timestamp: (subscription.started_at.end_of_month + 1.day).to_i,
        charges_from_datetime: subscription.started_at.beginning_of_day,
        charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
        charges_duration: 30.days
      )
    end

    context "when plan is weekly" do
      let(:boundaries) do
        BillingPeriodBoundaries.new(
          from_datetime: subscription.started_at.to_date.beginning_of_day,
          to_datetime: subscription.started_at.end_of_week.end_of_day,
          charges_from_datetime: subscription.started_at.to_date.beginning_of_day,
          charges_to_datetime: subscription.started_at.end_of_week.end_of_day,
          charges_duration: 30.days,
          timestamp: (subscription.started_at.end_of_week + 1.day).to_i
        )
      end

      before do
        plan.weekly!
      end

      context "when subscription start is on Monday" do
        let(:started_at) { Time.zone.parse("2022-06-20 00:01") }

        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 100,
            precise_amount_cents: 100.0,
            amount_currency: "EUR",
            unit_amount_cents: 100,
            precise_unit_amount: 1,
            units: 1
          )
        end

        context "when plan has a trial period" do
          before { plan.update(trial_period: trial_duration) }

          context "when trial end during period" do
            let(:trial_duration) { 3 }

            it "creates a fee with prorated amount based on trial" do
              result = fees_subscription_service.call

              # 100 - ((100/7)*3)
              expect(result.fee).to have_attributes(
                amount_cents: 57,
                precise_amount_cents: 57.14285714285714
              )
            end
          end

          context "when trial end after end of period" do
            let(:trial_duration) { 10 }

            it "creates a fee with zero amount" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 0,
                precise_amount_cents: 0.0
              )
            end
          end
        end

        context "when plan is pay in advance" do
          before { plan.update(pay_in_advance: true) }

          it "creates a fee" do
            result = fees_subscription_service.call

            expect(result.fee).to have_attributes(
              amount_cents: 100,
              precise_amount_cents: 100.0
            )
          end

          context "when plan has a trial period" do
            before { plan.update(trial_period: trial_duration) }

            context "when trial end in period" do
              let(:trial_duration) { 3 }

              it "creates a fee with prorated amount based on trial" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 57,
                  precise_amount_cents: 57.14285714285714
                )
              end
            end

            context "when trial end after period" do
              let(:trial_duration) { 10 }

              it "creates a fee with zero amount" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 0,
                  precise_amount_cents: 0.0
                )
              end
            end
          end
        end
      end

      context "when subscription start is on any other day" do
        let(:started_at) { Time.zone.parse("2022-06-22 00:00") }

        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 71,
            precise_amount_cents: 71.42857142857143,
            amount_currency: plan.amount_currency,
            units: 1
          )
        end

        context "when plan has a trial period" do
          before { plan.update(trial_period: trial_duration) }

          context "when trial end during the period" do
            let(:trial_duration) { 3 }

            it "creates a fee with prorated amount based on trial" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 29,
                precise_amount_cents: 28.57142857142857
              )
            end
          end

          context "when trial end after the period end" do
            let(:trial_duration) { 10 }

            it "creates a fee with zero amount" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 0,
                precise_amount_cents: 0.0
              )
            end
          end
        end

        context "when plan is pay in advance" do
          before { plan.update(pay_in_advance: true) }

          it "creates a fee" do
            result = fees_subscription_service.call

            expect(result.fee).to have_attributes(
              amount_cents: 71,
              precise_amount_cents: 71.42857142857143
            )
          end

          context "when plan has a trial period" do
            before { plan.update(trial_period: trial_duration) }

            context "when trial end during the period" do
              let(:trial_duration) { 3 }

              it "creates a fee with prorated amount based on trial" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 29,
                  precise_amount_cents: 28.57142857142857
                )
              end
            end

            context "when trial end after the period end" do
              let(:trial_duration) { 10 }

              it "creates a fee with zero amount" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 0,
                  precise_amount_cents: 0.0
                )
              end
            end
          end
        end

        context "when subscription is created in the past" do
          context "when plan is pay in advance" do
            let(:created_at) { subscription_at + 2.days }

            before { plan.update(pay_in_advance: true) }

            it "creates a full amount fee" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: result.fee.amount_cents,
                precise_amount_cents: result.fee.amount_cents
              )
            end
          end

          context "when subscription has started before previous billing period" do
            let(:created_at) { subscription_at + 8.days }

            let(:boundaries) do
              BillingPeriodBoundaries.new(
                from_datetime: subscription.created_at.beginning_of_week.beginning_of_day,
                to_datetime: subscription.created_at.end_of_week.end_of_day,
                timestamp: (subscription.created_at.end_of_week + 1.day).to_i,
                charges_from_datetime: subscription.started_at.beginning_of_day,
                charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
                charges_duration: 30.days
              )
            end

            it "creates a full amount fee" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: result.fee.amount_cents,
                precise_amount_cents: result.fee.amount_cents
              )
            end
          end
        end
      end
    end

    context "when plan is monthly" do
      before { plan.monthly! }

      context "when subscription start is on the 1st of the month" do
        let(:started_at) { Time.zone.parse("2022-01-01 00:01") }

        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 100,
            precise_amount_cents: 100.0,
            amount_currency: "EUR",
            unit_amount_cents: 100,
            precise_unit_amount: 1,
            units: 1
          )
        end

        context "when plan has a trial period" do
          before { plan.update(trial_period: trial_duration) }

          context "when trial end during period" do
            let(:trial_duration) { 3 }

            it "creates a fee with prorated amount based on trial" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 90,
                precise_amount_cents: 90.32258064516128
              )
            end
          end

          context "when trial end after end of period" do
            let(:trial_duration) { 45 }

            it "creates a fee with zero amount" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 0,
                precise_amount_cents: 0.0
              )
            end
          end
        end

        context "when plan is pay in advance" do
          let(:boundaries) do
            BillingPeriodBoundaries.new(
              from_datetime: subscription.started_at.to_date.beginning_of_day,
              to_datetime: subscription.started_at.end_of_month.end_of_day,
              charges_from_datetime: subscription.started_at.to_date.beginning_of_day,
              charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
              charges_duration: 30.days,
              timestamp: (subscription.started_at + 1.day).to_i
            )
          end

          before { plan.update(pay_in_advance: true) }

          it "creates a fee" do
            result = fees_subscription_service.call

            expect(result.fee).to have_attributes(
              amount_cents: 100,
              precise_amount_cents: 100.0
            )
          end

          context "when plan has a trial period" do
            before { plan.update(trial_period: trial_duration) }

            context "when trial end in period" do
              let(:trial_duration) { 3 }

              it "creates a fee with prorated amount based on trial" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 90,
                  precise_amount_cents: 90.32258064516128
                )
              end
            end

            context "when trial end after period" do
              let(:trial_duration) { 45 }

              it "creates a fee with zero amount" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 0,
                  precise_amount_cents: 0.0
                )
              end
            end
          end
        end
      end

      context "when subscription start is on any other day" do
        let(:started_at) { Time.zone.parse("2022-03-15 00:00:00") }

        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 55,
            precise_amount_cents: 54.83870967741935,
            amount_currency: plan.amount_currency,
            units: 1
          )
        end

        context "when plan has a trial period" do
          before { plan.update(trial_period: trial_duration) }

          context "when trial end during the period" do
            let(:trial_duration) { 3 }

            it "creates a fee with prorated amount based on trial" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 45,
                precise_amount_cents: 45.16129032258064
              )
            end
          end

          context "when trial end after the period end" do
            let(:trial_duration) { 45 }

            it "creates a fee with zero amount" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 0,
                precise_amount_cents: 0.0
              )
            end
          end
        end

        context "when plan is pay in advance" do
          let(:boundaries) do
            BillingPeriodBoundaries.new(
              from_datetime: subscription.started_at.to_date.beginning_of_day,
              to_datetime: subscription.started_at.end_of_month.end_of_day,
              charges_from_datetime: subscription.started_at.to_date.beginning_of_day,
              charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
              charges_duration: 30.days,
              timestamp: (subscription.started_at + 1.day).to_i
            )
          end

          before { plan.update(pay_in_advance: true) }

          it "creates a fee" do
            result = fees_subscription_service.call

            expect(result.fee).to have_attributes(
              amount_cents: 55,
              precise_amount_cents: 54.83870967741935
            )
          end

          context "when plan has a trial period" do
            before { plan.update(trial_period: trial_duration) }

            context "when trial end during the period" do
              let(:trial_duration) { 3 }

              it "creates a fee with prorated amount based on trial" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 45,
                  precise_amount_cents: 45.16129032258064
                )
              end
            end

            context "when trial end after the period end" do
              let(:trial_duration) { 45 }

              it "creates a fee with zero amount" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 0,
                  precise_amount_cents: 0.0
                )
              end
            end
          end
        end
      end

      context "when subscription is based on anniversary date" do
        let(:started_at) { Time.zone.parse("2022-08-31 00:01") }

        let(:plan) do
          create(
            :plan,
            amount_cents: 3000,
            amount_currency: "EUR"
          )
        end

        let(:subscription) do
          create(
            :subscription,
            plan:,
            started_at:,
            subscription_at: DateTime.parse("2022-08-31"),
            billing_time: :anniversary,
            customer:,
            external_id: "sub_id"
          )
        end

        let(:boundaries) do
          BillingPeriodBoundaries.new(
            from_datetime: Time.zone.parse("2022-08-31 00:00:00"),
            to_datetime: Time.zone.parse("2022-09-30 23:59:59"),
            charges_from_datetime: Time.zone.parse("2022-08-30 22:00:00"),
            charges_to_datetime: Time.zone.parse("2022-09-30 21:59:59"),
            charges_duration: 30.days,
            timestamp: Time.zone.parse("2022-10-01 00:00").to_i
          )
        end

        context "when subscription is pay in advance" do
          before { plan.update(pay_in_advance: true) }

          context "when plan has a trial period" do
            before { plan.update(trial_period: 15) }

            it "creates a fee with prorated amount based on trial" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 1600,
                precise_amount_cents: 1600.0
              )
            end

            context "with customer timezone" do
              let(:customer) { create(:customer, organization:, timezone: "Europe/Paris") }

              let(:boundaries) do
                BillingPeriodBoundaries.new(
                  from_datetime: Time.zone.parse("2022-08-30 22:00:00"),
                  to_datetime: Time.zone.parse("2022-09-30 21:59:59"),
                  charges_from_datetime: Time.zone.parse("2022-08-30 22:00:00"),
                  charges_to_datetime: Time.zone.parse("2022-09-30 21:59:59"),
                  charges_duration: 30.days,
                  timestamp: Time.zone.parse("2022-10-01 00:00").to_i
                )
              end

              it "creates a fee with prorated amount based on trial" do
                result = fees_subscription_service.call

                expect(result.fee).to have_attributes(
                  amount_cents: 1600,
                  precise_amount_cents: 1600.0
                )
              end
            end
          end
        end
      end
    end

    context "when plan is yearly" do
      before { plan.yearly! }

      context "when subscription start is on the 1st day of the year" do
        let(:started_at) { Time.zone.now.beginning_of_year }

        let(:boundaries) do
          BillingPeriodBoundaries.new(
            from_datetime: subscription.started_at.beginning_of_year.beginning_of_day,
            to_datetime: subscription.started_at.end_of_year.end_of_day,
            charges_from_datetime: subscription.started_at.beginning_of_day,
            charges_to_datetime: subscription.started_at.end_of_year.end_of_day,
            charges_duration: 30.days,
            timestamp: (subscription.started_at.end_of_year + 1.day).to_i
          )
        end

        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 100,
            precise_amount_cents: 100,
            amount_currency: "EUR",
            unit_amount_cents: 100,
            precise_unit_amount: 1,
            units: 1
          )
        end

        context "when plan is pay in advance" do
          let(:boundaries) do
            BillingPeriodBoundaries.new(
              from_datetime: subscription.started_at.beginning_of_year.beginning_of_day,
              to_datetime: subscription.started_at.end_of_year.end_of_day,
              charges_from_datetime: subscription.started_at.beginning_of_day,
              charges_to_datetime: subscription.started_at.end_of_year.end_of_day,
              charges_duration: 30.days,
              timestamp: subscription.started_at.beginning_of_year.beginning_of_day.to_i
            )
          end

          before { plan.update(pay_in_advance: true) }

          it "creates a fee" do
            result = fees_subscription_service.call

            expect(result.fee).to have_attributes(
              amount_cents: plan.amount_cents,
              precise_amount_cents: plan.amount_cents
            )
          end
        end
      end

      context "when subscription start is on any other day" do
        let(:started_at) { Time.zone.parse("2022-03-15 00:00:00") }

        let(:boundaries) do
          BillingPeriodBoundaries.new(
            from_datetime: subscription.started_at.beginning_of_day,
            to_datetime: subscription.started_at.end_of_year.end_of_day,
            charges_from_datetime: subscription.started_at.beginning_of_day,
            charges_to_datetime: subscription.started_at.end_of_year.end_of_day,
            charges_duration: 30.days,
            timestamp: (subscription.started_at.end_of_year + 1.day).to_i
          )
        end

        it "creates a fee" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            id: String,
            invoice_id: invoice.id,
            amount_cents: 80,
            precise_amount_cents: 80,
            amount_currency: plan.amount_currency,
            units: 1
          )
        end

        context "when plan is pay in advance" do
          before { plan.update(pay_in_advance: true) }

          it "creates a fee" do
            result = fees_subscription_service.call

            expect(result.fee).to have_attributes(
              amount_cents: 80,
              precise_amount_cents: 80.0
            )
          end
        end
      end
    end
  end

  context "when subscription has already been billed once on an other period" do
    let(:started_at) { Time.zone.parse("2022-01-01 00:00") }

    let(:boundaries) do
      BillingPeriodBoundaries.new(
        from_datetime: subscription.started_at.beginning_of_day,
        to_datetime: subscription.started_at.end_of_month.end_of_day,
        timestamp: (subscription.started_at.end_of_month + 1.day).to_i,
        charges_from_datetime: subscription.started_at.beginning_of_day,
        charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
        charges_duration: 30.days
      )
    end

    let(:invoice) do
      create(
        :invoice,
        issuing_date: subscription.started_at.end_of_month.to_date + 1.day
      )
    end

    before do
      other_invoice = create(:invoice, organization: customer.organization)
      create(:fee, subscription:, invoice: other_invoice)
    end

    it "creates a fee with full period amount" do
      result = fees_subscription_service.call

      expect(result.fee).to have_attributes(
        amount_cents: 100,
        precise_amount_cents: 100.0
      )
    end

    context "when plan has trial period" do
      context "when trial end during period" do
        before { plan.update(trial_period: 3) }

        it "creates a fee with prorated amount on trial period" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            amount_cents: 90,
            precise_amount_cents: 90.32258064516128
          )
        end

        context "when plan is pay in advance" do
          before do
            plan.update!(
              pay_in_advance: true,
              trial_period:,
              interval:
            )
          end

          context "when plan is weekly" do
            let(:boundaries) do
              BillingPeriodBoundaries.new(
                from_datetime: subscription.started_at.to_date.end_of_week.beginning_of_day,
                to_datetime: (subscription.started_at.end_of_week + 1.week).end_of_day,
                timestamp: (subscription.started_at.end_of_week + 1.day).to_i,
                charges_from_datetime: subscription.started_at.beginning_of_day,
                charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
                charges_duration: 30.days
              )
            end

            let(:interval) { :weekly }
            let(:trial_period) { 5 }

            it "creates a fee with prorated amount on trial period" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 57,
                precise_amount_cents: 57.14285714285714
              )
            end
          end

          context "when plan is monthly" do
            let(:interval) { :monthly }
            let(:trial_period) { 15 }

            let(:boundaries) do
              BillingPeriodBoundaries.new(
                from_datetime: subscription.started_at.beginning_of_day,
                to_datetime: subscription.started_at.end_of_month.end_of_day,
                timestamp: (subscription.started_at + 1.day).to_i,
                charges_from_datetime: subscription.started_at.beginning_of_day,
                charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
                charges_duration: 30.days
              )
            end

            it "creates a fee with prorated amount on trial period" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 52,
                precise_amount_cents: 51.61290322580645
              )
            end
          end

          context "when plan is yearly" do
            let(:boundaries) do
              BillingPeriodBoundaries.new(
                from_datetime: subscription.started_at.beginning_of_year.beginning_of_day,
                to_datetime: subscription.started_at.end_of_year.end_of_day,
                timestamp: (subscription.started_at.beginning_of_year + 1.day).to_i,
                charges_from_datetime: subscription.started_at.beginning_of_day,
                charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
                charges_duration: 30.days
              )
            end

            let(:interval) { :yearly }
            let(:trial_period) { 35 }

            it "creates a fee with prorated amount on trial period" do
              result = fees_subscription_service.call

              expect(result.fee).to have_attributes(
                amount_cents: 90,
                precise_amount_cents: 90.41095890410958
              )
            end
          end
        end
      end

      context "when trial end after period" do
        before { plan.update(trial_period: 45) }

        it "creates a fee with 0 amount" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            amount_cents: 0,
            precise_amount_cents: 0.0
          )
        end
      end
    end
  end

  context "when already billed fee" do
    let(:plan) do
      create(
        :plan,
        amount_cents: 100,
        amount_currency: "EUR"
      )
    end

    let(:started_at) { Time.zone.parse("2022-01-01 00:00:00") }

    let(:boundaries) do
      BillingPeriodBoundaries.new(
        from_datetime: (subscription.started_at + 1.month).beginning_of_day,
        to_datetime: (subscription.started_at + 2.months).end_of_day,
        timestamp: (subscription.started_at + 2.months + 1.day).to_i,
        charges_from_datetime: subscription.started_at.beginning_of_day,
        charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
        charges_duration: 30.days
      )
    end

    before do
      create(:fee, subscription:, invoice:)
    end

    it "does not create a fee" do
      expect { fees_subscription_service.call }.not_to change(Fee, :count)
    end
  end

  context "when billing a newly terminated subscription" do
    let(:started_at) { Time.zone.parse("2022-03-15 00:00:00") }

    let(:subscription) do
      create(
        :subscription,
        plan:,
        status: :terminated,
        started_at:,
        subscription_at:,
        customer:,
        external_id: "sub_id"
      )
    end

    let(:boundaries) do
      BillingPeriodBoundaries.new(
        from_datetime: subscription.started_at.beginning_of_month.beginning_of_day,
        to_datetime: (subscription.started_at + 5.days).end_of_day,
        timestamp: (subscription.started_at + 6.days).to_i,
        charges_from_datetime: subscription.started_at.beginning_of_day,
        charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
        charges_duration: 30.days
      )
    end

    before do
      plan.update!(pay_in_advance: false)
    end

    it "creates a fee" do
      result = fees_subscription_service.call

      expect(result.fee).to have_attributes(
        id: String,
        invoice_id: invoice.id,
        amount_cents: 65,
        precise_amount_cents: 64.51612903225806,
        amount_currency: plan.amount_currency,
        units: 1
      )
    end

    context "with customer timezone" do
      let(:customer) { create(:customer, organization:, timezone: "Europe/Paris") }
      let(:from_datetime) do
        subscription.started_at.to_date.beginning_of_month.in_time_zone(customer.applicable_timezone).utc
      end
      let(:to_datetime) do
        (subscription.started_at + 5.days).to_date.in_time_zone(customer.applicable_timezone).end_of_day.utc
      end
      let(:boundaries) do
        BillingPeriodBoundaries.new(
          from_datetime:,
          to_datetime:,
          timestamp: (subscription.started_at + 6.days).to_i,
          charges_from_datetime: subscription.started_at.beginning_of_day,
          charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
          charges_duration: 30.days
        )
      end

      it "creates a fee" do
        result = fees_subscription_service.call

        expect(result.fee).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          amount_cents: 65,
          precise_amount_cents: 64.51612903225806,
          amount_currency: plan.amount_currency,
          units: 1
        )
      end
    end

    context "when plan is weekly" do
      let(:boundaries) do
        BillingPeriodBoundaries.new(
          from_datetime: subscription.started_at.beginning_of_week.beginning_of_day,
          to_datetime: (subscription.started_at + 1.day).end_of_day,
          timestamp: (subscription.started_at + 2.days).to_i,
          charges_from_datetime: subscription.started_at.beginning_of_day,
          charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
          charges_duration: 30.days
        )
      end

      before do
        plan.weekly!
      end

      it "creates a fee" do
        result = fees_subscription_service.call

        expect(result.fee).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          amount_cents: 43,
          precise_amount_cents: 42.85714285714286,
          amount_currency: plan.amount_currency,
          units: 1
        )
      end
    end

    context "with a next subscription" do
      before do
        create(:subscription, previous_subscription: subscription)
      end

      it "creates a fee" do
        result = fees_subscription_service.call

        expect(result.fee).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          amount_cents: 61, # 100/31 * 19
          precise_amount_cents: 61.29032258064516, # 100/31 * 19
          amount_currency: plan.amount_currency,
          units: 1
        )
      end
    end

    context "when plan has trial period" do
      before do
        plan.update(trial_period: trial_duration)
        create(:subscription, previous_subscription: subscription)
      end

      context "when trial end before termination date" do
        let(:trial_duration) { 3 }

        it "creates a fee with prorated amount based on trial period" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            amount_cents: 6, # 2 days * (100 / 31)
            precise_amount_cents: 6.451612903225806 # 2 days * (100 / 31)
          )
        end
      end

      context "when trial end after termination date" do
        let(:trial_duration) { 45 }

        it "creates a fee with zero amount" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            amount_cents: 0,
            precise_amount_cents: 0.0
          )
        end
      end
    end
  end

  context "when billing a new upgraded subscription" do
    let(:previous_plan) { create(:plan, pay_in_advance: true, amount_cents: 80) }
    let(:previous_subscription) do
      create(
        :subscription,
        status: :terminated,
        plan: previous_plan,
        started_at: started_at - 6.months,
        customer:,
        external_id: "sub_id"
      )
    end
    let(:started_at) { Time.zone.parse("2022-03-15 00:00:00") }

    let(:subscription) do
      create(
        :subscription,
        plan:,
        started_at:,
        subscription_at:,
        previous_subscription:,
        customer:,
        external_id: "sub_id"
      )
    end

    let(:boundaries) do
      BillingPeriodBoundaries.new(
        from_datetime: subscription.started_at.beginning_of_day,
        to_datetime: subscription.started_at.end_of_month.end_of_day,
        timestamp: (subscription.started_at.end_of_month + 1.day).to_i,
        charges_from_datetime: subscription.started_at.beginning_of_day,
        charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
        charges_duration: 30.days
      )
    end

    before { previous_plan.update!(pay_in_advance: false) }

    it "creates a subscription fee" do
      result = fees_subscription_service.call

      expect(result.fee).to have_attributes(
        id: String,
        invoice_id: invoice.id,
        amount_cents: 55,
        precise_amount_cents: 54.83870967741935,
        amount_currency: plan.amount_currency,
        units: 1
      )
    end

    context "with customer timezone" do
      let(:customer) { create(:customer, organization:, timezone: "Europe/Paris") }
      let(:from_datetime) do
        subscription.started_at.in_time_zone(customer.applicable_timezone).beginning_of_day.utc
      end
      let(:to_datetime) do
        subscription.started_at.end_of_month.to_date.in_time_zone(customer.applicable_timezone).end_of_day.utc
      end

      let(:boundaries) do
        BillingPeriodBoundaries.new(
          from_datetime:,
          to_datetime:,
          timestamp: (subscription.started_at + 17.days).to_i,
          charges_from_datetime: subscription.started_at.beginning_of_day,
          charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
          charges_duration: 30.days
        )
      end

      it "creates a subscription fee" do
        result = fees_subscription_service.call

        expect(result.fee).to have_attributes(
          id: String,
          invoice_id: invoice.id,
          amount_cents: 55,
          precise_amount_cents: 54.83870967741935,
          amount_currency: plan.amount_currency,
          units: 1
        )
      end
    end

    context "when plan has trial period" do
      before { plan.update(trial_period: trial_duration) }

      context "when trial period end before period end" do
        let(:trial_duration) { (subscription.started_at.to_date - previous_subscription.started_at.to_date).to_i + 3 }

        it "creates a fee with prorated amount based on the trial" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            amount_cents: 45,
            precise_amount_cents: 45.16129032258064
          )
        end
      end

      context "when trial period end after period end" do
        let(:trial_duration) do
          (subscription.started_at.to_date - previous_subscription.started_at.to_date).to_i + 45
        end

        it "creates a fee with zero amount" do
          result = fees_subscription_service.call

          expect(result.fee).to have_attributes(
            amount_cents: 0,
            precise_amount_cents: 0.0
          )
        end
      end
    end

    context "when new plan is pay in advance" do
      before do
        plan.update(pay_in_advance: true)
        subscription.previous_subscription.update(terminated_at: subscription.started_at)
      end

      let(:boundaries) do
        BillingPeriodBoundaries.new(
          from_datetime: subscription.started_at,
          to_datetime: subscription.started_at.end_of_month,
          timestamp: subscription.started_at.to_i,
          charges_from_datetime: subscription.started_at.beginning_of_day,
          charges_to_datetime: subscription.started_at.end_of_month.end_of_day,
          charges_duration: 30.days
        )
      end

      it "creates a subscription fee" do
        result = fees_subscription_service.call

        expect(result.fee).to have_attributes(
          amount_cents: 55,
          precise_amount_cents: 54.83870967741935
        )
      end
    end
  end
end
