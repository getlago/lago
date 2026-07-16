# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyUsages::FillFromInvoiceService do
  subject(:fill_service) { described_class.new(invoice:, subscriptions:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, timezone: "America/New_York") }
  let(:subscription) { create(:subscription, customer:) }
  let(:subscriptions) { [subscription] }

  let(:timestamp) { Time.parse("2025-07-01 04:10:02.000000000 UTC") }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      issuing_date: Time.zone.at(timestamp).to_date,
      customer:
    )
  end

  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      subscription:,
      invoice:,
      timestamp:,
      from_datetime: Time.parse("2025-06-06 04:00:00.000000000 +0000"),
      to_datetime: Time.parse("2025-07-01 03:59:59.999999000 +0000"),
      charges_from_datetime: Time.parse("2025-06-07 04:00:00.000000000 +0000"),
      charges_to_datetime: Time.parse("2025-07-01 03:59:59.999999000 +0000")
    )
  end

  let(:usage_date) do
    invoice_subscription.charges_to_datetime.in_time_zone(invoice.customer.applicable_timezone).to_date
  end

  before { invoice_subscription }

  describe "#call" do
    context "when there is no usage" do
      it "does not create a daily usage" do
        travel_to(timestamp) do
          expect { fill_service.call }.not_to change(DailyUsage, :count)
        end
      end
    end

    # More context in spec/scenarios/daily_usages/yearly_plan_with_monthly_fixed_charges_spec.rb
    context "when invoice_subscription has nil charges_from_datetime" do
      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          subscription:,
          invoice:,
          timestamp:,
          from_datetime: Time.parse("2025-06-06 04:00:00.000000000 +0000"),
          to_datetime: Time.parse("2025-07-01 03:59:59.999999000 +0000"),
          charges_from_datetime: nil,
          charges_to_datetime: nil
        )
      end

      before do
        charge = create(:standard_charge, plan: subscription.plan)
        create(:charge_fee, invoice:, charge:, units: 12, amount_cents: 1200, subscription:)
      end

      it "skips the invoice_subscription" do
        travel_to(timestamp) do
          expect { fill_service.call }.not_to change(DailyUsage, :count)
        end
      end
    end

    # TODO: investigate why this happens
    context "when invoice_subscription has charges_from_datetime > charges_to_datetime" do
      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          subscription:,
          invoice:,
          timestamp:,
          from_datetime: Time.parse("2025-06-06 04:00:00.000000000 +0000"),
          to_datetime: Time.parse("2025-07-01 03:59:59.999999000 +0000"),
          charges_from_datetime: Time.parse("2025-07-01 03:59:59.999999000 +0000"),
          charges_to_datetime: Time.parse("2025-06-07 04:00:00.000000000 +0000")
        )
      end

      before do
        charge = create(:standard_charge, plan: subscription.plan)
        create(:charge_fee, invoice:, charge:, units: 12, amount_cents: 1200, subscription:)
      end

      it "skips the invoice_subscription" do
        travel_to(timestamp) do
          expect { fill_service.call }.not_to change(DailyUsage, :count)
        end
      end
    end

    context "when there is usage" do
      before do
        charge = create(:standard_charge, plan: subscription.plan)
        create(:charge_fee, invoice:, charge:, units: 12, amount_cents: 1200, subscription:)
      end

      it "creates daily usages for the subscriptions" do
        travel_to(timestamp) do
          expect { fill_service.call }.to change(DailyUsage, :count).by(1)

          daily_usage = subscription.daily_usages.order(:created_at).last
          expect(daily_usage).to have_attributes(
            organization:,
            customer:,
            subscription:,
            external_subscription_id: subscription.external_id,
            usage: Hash,
            from_datetime: invoice_subscription.charges_from_datetime.change(usec: 0),
            to_datetime: invoice_subscription.charges_to_datetime.change(usec: 0),
            refreshed_at: invoice_subscription.timestamp,
            usage_diff: Hash,
            usage_date:
          )
        end
      end

      context "when invoice contains fees with 0 units" do
        it "does not include those fees in the usage" do
          charge = create(:standard_charge, plan: subscription.plan)
          create(:charge_fee, invoice:, charge:, units: 0, amount_cents: 0, subscription:)

          travel_to(timestamp) do
            expect { fill_service.call }.to change(DailyUsage, :count).by(1)
            daily_usage = subscription.daily_usages.order(:created_at).last
            expect(daily_usage.usage["charges_usage"].count).to eq(1)
          end
        end
      end

      context "when the only consumed charge is free (zero amount)" do
        before do
          invoice.fees.charge.destroy_all
          charge = create(:standard_charge, plan: subscription.plan, properties: {"amount" => "0"})
          create(:charge_fee, invoice:, charge:, units: 5, amount_cents: 0, taxes_amount_cents: 0, subscription:)
        end

        it "creates a daily usage based on consumed units" do
          travel_to(timestamp) do
            expect { fill_service.call }.to change(DailyUsage, :count).by(1)

            daily_usage = subscription.daily_usages.order(:created_at).last
            expect(daily_usage.usage["amount_cents"]).to eq(0)
            expect(daily_usage.usage["charges_usage"].count).to eq(1)
          end
        end
      end

      context "when the daily usage already exists" do
        before do
          create(
            :daily_usage,
            organization:,
            customer:,
            subscription:,
            external_subscription_id: subscription.external_id,
            from_datetime: invoice_subscription.charges_from_datetime.change(usec: 0),
            to_datetime: invoice_subscription.charges_to_datetime.change(usec: 0),
            refreshed_at: invoice_subscription.timestamp,
            usage_date:
          )
        end

        it "does not create a new daily usage" do
          expect { fill_service.call }.not_to change(DailyUsage, :count)
        end
      end

      context "when multiples subscriptions are passed to the service" do
        let(:subscription2) { create(:subscription, customer:) }
        let(:subscriptions) { [subscription, subscription2] }

        let(:invoice_subscription2) do
          create(
            :invoice_subscription,
            subscription: subscription2,
            invoice:,
            timestamp:,
            from_datetime: Time.parse("2025-06-06 04:00:00.000000000 +0000"),
            to_datetime: Time.parse("2025-07-01 03:59:59.999999000 +0000"),
            charges_from_datetime: Time.parse("2025-06-07 04:00:00.000000000 +0000"),
            charges_to_datetime: Time.parse("2025-07-01 03:59:59.999999000 +0000")
          )
        end

        before do
          invoice_subscription2
          charge = create(:standard_charge, plan: subscription2.plan)
          create(:charge_fee, invoice:, charge:, units: 12, amount_cents: 1200, subscription: subscription2)
        end

        it "creates daily usages for all the subscriptions" do
          expect { fill_service.call }.to change(DailyUsage, :count).by(2)
        end

        context "when only one subscription has to be updated" do
          let(:subscriptions) { [subscription] }

          it "creates daily usages for the subscriptions" do
            expect { fill_service.call }.to change(DailyUsage, :count).by(1)

            daily_usage = subscription.daily_usages.order(:created_at).last
            expect(daily_usage).to have_attributes(
              organization:,
              customer:,
              subscription:,
              external_subscription_id: subscription.external_id,
              usage: Hash,
              from_datetime: invoice_subscription.charges_from_datetime.change(usec: 0),
              to_datetime: invoice_subscription.charges_to_datetime.change(usec: 0),
              refreshed_at: invoice_subscription.timestamp,
              usage_diff: Hash,
              usage_date:
            )
          end
        end
      end
    end
  end

  describe "#existing_daily_usage" do
    context "when no daily usage exists" do
      it "returns nil" do
        result = fill_service.send(:existing_daily_usage, invoice_subscription)
        expect(result).to be_nil
      end
    end

    context "when no matching daily usage exists" do
      before do
        create(
          :daily_usage,
          organization: invoice.organization,
          customer: invoice.customer,
          subscription: subscription,
          external_subscription_id: subscription.external_id,
          from_datetime: invoice_subscription.charges_from_datetime,
          to_datetime: invoice_subscription.charges_to_datetime,
          refreshed_at: invoice_subscription.timestamp,
          usage_date:
        )
      end

      it "returns nil" do
        result = fill_service.send(:existing_daily_usage, invoice_subscription)
        expect(result).to be_nil
      end
    end

    context "when a matching daily usage exists" do
      let!(:existing_usage) do
        create(
          :daily_usage,
          organization: invoice.organization,
          customer: invoice.customer,
          subscription: subscription,
          external_subscription_id: subscription.external_id,
          from_datetime: invoice_subscription.charges_from_datetime.change(usec: 0),
          to_datetime: invoice_subscription.charges_to_datetime.change(usec: 0),
          refreshed_at: invoice_subscription.timestamp,
          usage_date:
        )
      end

      it "returns the existing daily usage" do
        result = fill_service.send(:existing_daily_usage, invoice_subscription)
        expect(result).to eq(existing_usage)
      end
    end
  end

  describe "#invoice_usage" do
    subject(:usage) { fill_service.send(:invoice_usage, subscription, invoice_subscription) }

    let(:charge) { create(:standard_charge, plan: subscription.plan) }

    it "returns an OpenStruct with correct datetime attributes" do
      expect(usage.from_datetime).to eq(invoice_subscription.charges_from_datetime.change(usec: 0))
      expect(usage.to_datetime).to eq(invoice_subscription.charges_to_datetime.change(usec: 0))
    end

    it "returns the issuing_date as an ISO8601 string" do
      expect(usage.issuing_date).to eq(invoice.issuing_date.iso8601)
    end

    context "when invoice contains fees that should be excluded" do
      let(:charge_fee) do
        create(
          :charge_fee,
          invoice:,
          charge:,
          subscription:,
          units: 10,
          amount_cents: 1000,
          taxes_amount_cents: 100
        )
      end

      let(:in_advance_fee) do
        create(
          :charge_fee,
          subscription:,
          pay_in_advance: true,
          pay_in_advance_event_transaction_id: 1,
          properties: {
            "charges_from_datetime" => invoice_subscription.charges_from_datetime.iso8601(3),
            "charges_to_datetime" => invoice_subscription.charges_to_datetime.iso8601(3)
          }
        )
      end

      before do
        charge_fee
        in_advance_fee
        create(:fee, invoice:, subscription:)
      end

      it "includes fees with positive units belonging to the subscription and in advance fees" do
        result = fill_service.send(:invoice_usage, subscription, invoice_subscription)

        expect(result.fees.count).to eq(2)
        expect(result.fees).to contain_exactly(charge_fee, in_advance_fee)
        expect(result.total_amount_cents).to eq(1302)
      end
    end
  end

  describe "#in_advance_fees" do
    subject(:in_advance_fees) { fill_service.send(:in_advance_fees, subscription, invoice_subscription) }

    context "when invoice_subscription times have only seconds" do
      let(:timestamp) { Time.zone.parse("2024-12-01T00:00:00") }
      let(:end_timestamp) { Time.zone.parse("2024-12-31T23:59:59") }

      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          subscription: subscription,
          invoice: invoice,
          timestamp: timestamp,
          from_datetime: timestamp,
          to_datetime: end_timestamp,
          charges_from_datetime: timestamp,
          charges_to_datetime: end_timestamp
        )
      end

      before do
        create(
          :charge_fee,
          subscription: subscription,
          pay_in_advance: true,
          pay_in_advance_event_transaction_id: 1,
          properties: {
            "charges_from_datetime" => invoice_subscription.charges_from_datetime.iso8601,
            "charges_to_datetime" => invoice_subscription.charges_to_datetime.iso8601
          }
        )
      end

      it "returns the matching in-advance fee" do
        fees = in_advance_fees.to_a

        expect(fees.count).to eq(1)
        expect(fees.first.subscription_id).to eq(subscription.id)
      end
    end

    context "when invoice_subscription times have miliseconds" do
      let(:timestamp) { Time.zone.parse("2024-12-01T00:00:00.000") }
      let(:end_timestamp) { Time.zone.parse("2024-12-31T23:59:59.000") }

      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          subscription: subscription,
          invoice: invoice,
          timestamp: timestamp,
          from_datetime: timestamp,
          to_datetime: end_timestamp,
          charges_from_datetime: timestamp,
          charges_to_datetime: end_timestamp
        )
      end

      before do
        create(
          :charge_fee,
          subscription: subscription,
          pay_in_advance: true,
          pay_in_advance_event_transaction_id: 1,
          properties: {
            "charges_from_datetime" => invoice_subscription.charges_from_datetime.iso8601(3),
            "charges_to_datetime" => invoice_subscription.charges_to_datetime.iso8601(3)
          }
        )
      end

      it "returns the matching in-advance fee" do
        fees = in_advance_fees.to_a

        expect(fees.count).to eq(1)
        expect(fees.first.subscription_id).to eq(subscription.id)
      end
    end
  end

  describe "#usage_date" do
    subject(:local_date) { fill_service.send(:usage_date, invoice_subscription) }

    it "returns the charges_to_datetime in the customer's timezone as a date" do
      # It is still June 30th in America/New_York timezone
      # even if charges_to_datetime: Time.parse("2025-07-01 03:59:59.999999000 +0000")
      expect(local_date).to eq(Date.parse("2025-06-30"))
      expect(local_date).not_to eq(Date.parse("2025-07-01"))
    end
  end
end
