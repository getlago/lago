# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeBoundariesHelper do
  subject(:helper) { described_class }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, interval: :monthly) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      subscription:,
      invoice:,
      from_datetime: DateTime.parse("2025-12-01T00:00:00"),
      to_datetime: DateTime.parse("2025-12-31T23:59:59"),
      charges_from_datetime: DateTime.parse("2025-12-01T00:00:00"),
      charges_to_datetime: DateTime.parse("2025-12-31T23:59:59"),
      fixed_charges_from_datetime: DateTime.parse("2025-12-01T00:00:00"),
      fixed_charges_to_datetime: DateTime.parse("2025-12-31T23:59:59"),
      timestamp: DateTime.parse("2026-01-01T00:00:00")
    )
  end

  describe ".group_fees_by_billing_period" do
    let(:subscription_fee) do
      create(
        :fee,
        fee_type: :subscription,
        subscription:,
        invoice:,
        properties: {
          "from_datetime" => "2025-12-01T00:00:00Z",
          "to_datetime" => "2025-12-31T23:59:59Z"
        }
      )
    end

    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:charge) { create(:standard_charge, plan:, billable_metric:) }
    let(:charge_fee_arrears) do
      create(
        :charge_fee,
        charge:,
        subscription:,
        invoice:,
        properties: {
          "charges_from_datetime" => "2025-12-01T00:00:00Z",
          "charges_to_datetime" => "2025-12-31T23:59:59Z"
        }
      )
    end

    let(:charge_fee_advance) do
      create(
        :charge_fee,
        charge:,
        subscription:,
        invoice:,
        properties: {
          "charges_from_datetime" => "2026-01-01T00:00:00Z",
          "charges_to_datetime" => "2026-01-31T23:59:59Z"
        }
      )
    end

    let(:fees) { [subscription_fee, charge_fee_arrears, charge_fee_advance] }

    it "groups fees by their billing period" do
      grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

      expect(grouped.size).to eq(2)
    end

    it "sorts groups chronologically" do
      grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

      expect(grouped.first.billing_period.from_datetime.to_date).to eq(Date.new(2025, 12, 1))
      expect(grouped.last.billing_period.from_datetime.to_date).to eq(Date.new(2026, 1, 1))
    end

    it "includes subscription fee in correct group" do
      grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

      december_group = grouped.find { |g| g.billing_period.from_datetime.to_date == Date.new(2025, 12, 1) }
      expect(december_group.subscription_fee).to eq(subscription_fee)
    end

    it "includes charge fees in correct groups" do
      grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

      december_group = grouped.find { |g| g.billing_period.from_datetime.to_date == Date.new(2025, 12, 1) }
      january_group = grouped.find { |g| g.billing_period.from_datetime.to_date == Date.new(2026, 1, 1) }

      expect(december_group.charge_fees).to include(charge_fee_arrears)
      expect(january_group.charge_fees).to include(charge_fee_advance)
    end

    context "with fixed charge fees" do
      let(:add_on) { create(:add_on, organization:) }
      let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }
      let(:fixed_charge_fee_december) do
        create(
          :fixed_charge_fee,
          fixed_charge:,
          subscription:,
          invoice:,
          properties: {
            "fixed_charges_from_datetime" => "2025-12-01T00:00:00Z",
            "fixed_charges_to_datetime" => "2025-12-31T23:59:59Z"
          }
        )
      end

      let(:fixed_charge_fee_january) do
        create(
          :fixed_charge_fee,
          fixed_charge:,
          subscription:,
          invoice:,
          properties: {
            "fixed_charges_from_datetime" => "2026-01-01T00:00:00Z",
            "fixed_charges_to_datetime" => "2026-01-31T23:59:59Z"
          }
        )
      end

      it "groups fixed charge fees by billing period" do
        fees = [fixed_charge_fee_december, fixed_charge_fee_january]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        expect(grouped.size).to eq(2)
        december_group = grouped.find { |g| g.billing_period.from_datetime.to_date == Date.new(2025, 12, 1) }
        january_group = grouped.find { |g| g.billing_period.from_datetime.to_date == Date.new(2026, 1, 1) }

        expect(december_group.fixed_charge_fees).to include(fixed_charge_fee_december)
        expect(january_group.fixed_charge_fees).to include(fixed_charge_fee_january)
      end

      it "includes multiple fixed charge fees in same period" do
        fixed_charge2 = create(:fixed_charge, plan:, add_on:)
        fixed_charge_fee2 = create(
          :fixed_charge_fee,
          fixed_charge: fixed_charge2,
          subscription:,
          invoice:,
          properties: {
            "fixed_charges_from_datetime" => "2025-12-01T00:00:00Z",
            "fixed_charges_to_datetime" => "2025-12-31T23:59:59Z"
          }
        )

        fees = [fixed_charge_fee_december, fixed_charge_fee2]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        december_group = grouped.find { |g| g.billing_period.from_datetime.to_date == Date.new(2025, 12, 1) }
        expect(december_group.fixed_charge_fees.size).to eq(2)
        expect(december_group.fixed_charge_fees).to include(fixed_charge_fee_december, fixed_charge_fee2)
      end
    end

    context "with commitment fees" do
      let(:commitment) { create(:commitment, :minimum_commitment, plan:) }

      context "with properties" do
        let(:commitment_fee) do
          create(
            :minimum_commitment_fee,
            subscription:,
            invoice:,
            properties: {
              "from_datetime" => "2025-12-01T00:00:00Z",
              "to_datetime" => "2025-12-31T23:59:59Z"
            }
          )
        end

        it "groups commitment fee by billing period from properties" do
          fees = [commitment_fee]
          grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

          expect(grouped.size).to eq(1)
          expect(grouped.first.billing_period.from_datetime.to_date).to eq(Date.new(2025, 12, 1))
          expect(grouped.first.commitment_fee).to eq(commitment_fee)
        end
      end

      context "without properties for pay_in_arrears plan" do
        let(:plan_arrears) { create(:plan, organization:, interval: :monthly, pay_in_advance: false) }
        let(:subscription_arrears) { create(:subscription, customer:, plan: plan_arrears) }
        let(:invoice_subscription_arrears) do
          create(
            :invoice_subscription,
            subscription: subscription_arrears,
            invoice:,
            from_datetime: DateTime.parse("2025-12-01T00:00:00"),
            to_datetime: DateTime.parse("2025-12-31T23:59:59")
          )
        end

        let(:commitment_fee) do
          create(
            :minimum_commitment_fee,
            subscription: subscription_arrears,
            invoice:,
            properties: {}
          )
        end

        it "uses current invoice_subscription boundaries" do
          fees = [commitment_fee]
          grouped = helper.group_fees_by_billing_period(fees, invoice_subscription: invoice_subscription_arrears)

          expect(grouped.size).to eq(1)
          expect(grouped.first.billing_period.from_datetime).to eq(invoice_subscription_arrears.from_datetime)
          expect(grouped.first.billing_period.to_datetime).to eq(invoice_subscription_arrears.to_datetime)
        end
      end

      context "without properties for pay_in_advance plan" do
        let(:plan_advance) { create(:plan, organization:, interval: :monthly, pay_in_advance: true) }
        let(:subscription_advance) { create(:subscription, customer:, plan: plan_advance) }
        let(:previous_invoice_subscription) do
          create(
            :invoice_subscription,
            subscription: subscription_advance,
            invoice: create(:invoice, customer:, organization:),
            from_datetime: DateTime.parse("2025-11-01T00:00:00"),
            to_datetime: DateTime.parse("2025-11-30T23:59:59"),
            timestamp: DateTime.parse("2025-12-01T00:00:00")
          )
        end

        let(:invoice_subscription_advance) do
          create(
            :invoice_subscription,
            subscription: subscription_advance,
            invoice:,
            from_datetime: DateTime.parse("2025-12-01T00:00:00"),
            to_datetime: DateTime.parse("2025-12-31T23:59:59"),
            timestamp: DateTime.parse("2026-01-01T00:00:00")
          )
        end

        let(:commitment_fee) do
          create(
            :minimum_commitment_fee,
            subscription: subscription_advance,
            invoice:,
            properties: {}
          )
        end

        before do
          # Create subscription fee on previous invoice subscription to make it findable
          create(:fee, fee_type: :subscription, subscription: subscription_advance, invoice: previous_invoice_subscription.invoice)
        end

        it "uses previous invoice_subscription boundaries" do
          fees = [commitment_fee]
          grouped = helper.group_fees_by_billing_period(fees, invoice_subscription: invoice_subscription_advance)

          expect(grouped.size).to eq(1)
          expect(grouped.first.billing_period.from_datetime).to eq(previous_invoice_subscription.from_datetime)
          expect(grouped.first.billing_period.to_datetime).to eq(previous_invoice_subscription.to_datetime)
        end
      end

      context "with empty string properties" do
        let(:commitment_fee) do
          create(
            :minimum_commitment_fee,
            subscription:,
            invoice:,
            properties: {
              "from_datetime" => "",
              "to_datetime" => ""
            }
          )
        end

        it "falls back to invoice_subscription boundaries" do
          fees = [commitment_fee]
          grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

          expect(grouped.size).to eq(1)
          expect(grouped.first.billing_period.from_datetime).to eq(invoice_subscription.from_datetime)
          expect(grouped.first.billing_period.to_datetime).to eq(invoice_subscription.to_datetime)
        end
      end
    end

    context "with multiple fees of same type in same period" do
      let(:charge2) { create(:standard_charge, plan:, billable_metric: create(:billable_metric, organization:)) }
      let(:charge_fee2) do
        create(
          :charge_fee,
          charge: charge2,
          subscription:,
          invoice:,
          properties: {
            "charges_from_datetime" => "2025-12-01T00:00:00Z",
            "charges_to_datetime" => "2025-12-31T23:59:59Z"
          }
        )
      end

      it "includes all charge fees in same group" do
        fees = [charge_fee_arrears, charge_fee2]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        december_group = grouped.find { |g| g.billing_period.from_datetime.to_date == Date.new(2025, 12, 1) }
        expect(december_group.charge_fees.size).to eq(2)
        expect(december_group.charge_fees).to include(charge_fee_arrears, charge_fee2)
      end

      it "sorts charge fees alphabetically within group" do
        # Create fees with different invoice_sorting_clause values
        allow(charge_fee_arrears).to receive(:invoice_sorting_clause).and_return("charge b")
        allow(charge_fee2).to receive(:invoice_sorting_clause).and_return("charge a")

        fees = [charge_fee_arrears, charge_fee2]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        december_group = grouped.find { |g| g.billing_period.from_datetime.to_date == Date.new(2025, 12, 1) }
        expect(december_group.charge_fees.first).to eq(charge_fee2)
        expect(december_group.charge_fees.last).to eq(charge_fee_arrears)
      end
    end

    context "with missing properties" do
      context "when subscription fees" do
        let(:subscription_fee_missing) do
          create(
            :fee,
            fee_type: :subscription,
            subscription:,
            invoice:,
            properties: {}
          )
        end

        it "falls back to invoice_subscription boundaries" do
          fees = [subscription_fee_missing]
          grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

          expect(grouped.size).to eq(1)
          expect(grouped.first.billing_period.from_datetime).to eq(invoice_subscription.from_datetime)
          expect(grouped.first.billing_period.to_datetime).to eq(invoice_subscription.to_datetime)
        end
      end

      context "when charge fees" do
        let(:charge_fee_missing) do
          create(
            :charge_fee,
            charge:,
            subscription:,
            invoice:,
            properties: {}
          )
        end

        it "falls back to invoice_subscription charge boundaries" do
          fees = [charge_fee_missing]
          grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

          expect(grouped.size).to eq(1)
          expect(grouped.first.billing_period.from_datetime).to eq(invoice_subscription.charges_from_datetime)
          expect(grouped.first.billing_period.to_datetime).to eq(invoice_subscription.charges_to_datetime)
        end
      end

      context "when fixed charge fees" do
        let(:add_on) { create(:add_on, organization:) }
        let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }
        let(:fixed_charge_fee_missing) do
          create(
            :fixed_charge_fee,
            fixed_charge:,
            subscription:,
            invoice:,
            properties: {}
          )
        end

        it "falls back to invoice_subscription fixed charge boundaries" do
          fees = [fixed_charge_fee_missing]
          grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

          expect(grouped.size).to eq(1)
          expect(grouped.first.billing_period.from_datetime).to eq(invoice_subscription.fixed_charges_from_datetime)
          expect(grouped.first.billing_period.to_datetime).to eq(invoice_subscription.fixed_charges_to_datetime)
        end
      end
    end

    context "with unknown fee types" do
      let(:add_on_fee) do
        create(
          :add_on_fee,
          invoice:,
          properties: {}
        )
      end

      let(:credit_fee) do
        create(
          :credit_fee,
          invoice:,
          properties: {}
        )
      end

      it "ignores add_on fees (not added to any group)" do
        fees = [add_on_fee]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        # Unknown fee types are not handled by the case statement, so they're not added to any group
        expect(grouped).to be_empty
      end

      it "ignores credit fees (not added to any group)" do
        fees = [credit_fee]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        # Unknown fee types are not handled by the case statement, so they're not added to any group
        expect(grouped).to be_empty
      end
    end

    it "groups fees with same date but different times together" do
      charge_fee_different_time = create(
        :charge_fee,
        charge:,
        subscription:,
        invoice:,
        properties: {
          "charges_from_datetime" => "2025-12-01T12:00:00Z",
          "charges_to_datetime" => "2025-12-31T12:00:00Z"
        }
      )

      fees = [charge_fee_arrears, charge_fee_different_time]
      grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

      expect(grouped.size).to eq(1)
      expect(grouped.first.charge_fees.size).to eq(2)
    end

    context "with mixed fee types in same period" do
      let(:fixed_charge) { create(:fixed_charge, plan:) }
      let(:commitment) { create(:commitment, :minimum_commitment, plan:) }

      let(:fixed_charge_fee) do
        create(
          :fixed_charge_fee,
          fixed_charge:,
          subscription:,
          invoice:,
          properties: {
            "fixed_charges_from_datetime" => "2025-12-01T00:00:00Z",
            "fixed_charges_to_datetime" => "2025-12-31T23:59:59Z"
          }
        )
      end

      let(:commitment_fee) do
        create(
          :minimum_commitment_fee,
          subscription:,
          invoice:,
          properties: {
            "from_datetime" => "2025-12-01T00:00:00Z",
            "to_datetime" => "2025-12-31T23:59:59Z"
          }
        )
      end

      it "includes all fee types in the same group" do
        fees = [subscription_fee, charge_fee_arrears, fixed_charge_fee, commitment_fee]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        expect(grouped.size).to eq(1)
        december_group = grouped.first

        expect(december_group.subscription_fee).to eq(subscription_fee)
        expect(december_group.charge_fees).to include(charge_fee_arrears)
        expect(december_group.fixed_charge_fees).to include(fixed_charge_fee)
        expect(december_group.commitment_fee).to eq(commitment_fee)
      end
    end

    context "with invalid datetime properties" do
      it "handles nil datetime values" do
        subscription_fee_nil = create(
          :fee,
          fee_type: :subscription,
          subscription:,
          invoice:,
          properties: {
            "from_datetime" => nil,
            "to_datetime" => nil
          }
        )

        fees = [subscription_fee_nil]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        expect(grouped.size).to eq(1)
        expect(grouped.first.billing_period.from_datetime).to eq(invoice_subscription.from_datetime)
        expect(grouped.first.billing_period.to_datetime).to eq(invoice_subscription.to_datetime)
      end

      it "creates billing period with nil values for invalid datetime strings" do
        subscription_fee_invalid = create(
          :fee,
          fee_type: :subscription,
          subscription:,
          invoice:,
          properties: {
            "from_datetime" => "invalid-date",
            "to_datetime" => "invalid-date"
          }
        )

        fees = [subscription_fee_invalid]
        grouped = helper.group_fees_by_billing_period(fees, invoice_subscription:)

        # When parse_datetime fails, it returns nil, and BillingPeriod is created with nil values
        # The from && to check passes because the strings exist, but parse_datetime returns nil
        expect(grouped.size).to eq(1)
        expect(grouped.first.billing_period.from_datetime).to be_nil
        expect(grouped.first.billing_period.to_datetime).to be_nil
      end
    end
  end

  describe ".billing_period_for" do
    context "when fee is a subscription fee" do
      let(:fee) do
        create(
          :fee,
          fee_type: :subscription,
          subscription:,
          invoice:,
          properties: {
            "from_datetime" => "2026-01-01T00:00:00Z",
            "to_datetime" => "2026-01-31T23:59:59Z"
          }
        )
      end

      it "returns the billing period from fee properties" do
        period = helper.billing_period_for(fee, invoice_subscription:)

        expect(period.from_datetime.to_date).to eq(Date.new(2026, 1, 1))
        expect(period.to_datetime.to_date).to eq(Date.new(2026, 1, 31))
      end
    end

    context "when fee is a charge fee" do
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:charge) { create(:standard_charge, plan:, billable_metric:) }
      let(:fee) do
        create(
          :charge_fee,
          charge:,
          subscription:,
          invoice:,
          properties: {
            "charges_from_datetime" => "2026-01-01T00:00:00Z",
            "charges_to_datetime" => "2026-01-31T23:59:59Z"
          }
        )
      end

      it "returns the billing period from charge boundaries in fee properties" do
        period = helper.billing_period_for(fee, invoice_subscription:)

        expect(period.from_datetime.to_date).to eq(Date.new(2026, 1, 1))
        expect(period.to_datetime.to_date).to eq(Date.new(2026, 1, 31))
      end
    end

    context "when fee is a fixed charge fee" do
      let(:add_on) { create(:add_on, organization:) }
      let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }
      let(:fee) do
        create(
          :fixed_charge_fee,
          fixed_charge:,
          subscription:,
          invoice:,
          properties: {
            "fixed_charges_from_datetime" => "2026-01-01T00:00:00Z",
            "fixed_charges_to_datetime" => "2026-01-31T23:59:59Z"
          }
        )
      end

      it "returns the billing period from fixed charge boundaries in fee properties" do
        period = helper.billing_period_for(fee, invoice_subscription:)

        expect(period.from_datetime.to_date).to eq(Date.new(2026, 1, 1))
        expect(period.to_datetime.to_date).to eq(Date.new(2026, 1, 31))
      end
    end

    context "when fee is a commitment fee with properties" do
      let(:commitment) { create(:commitment, :minimum_commitment, plan:) }
      let(:fee) do
        create(
          :minimum_commitment_fee,
          subscription:,
          invoice:,
          properties: {
            "from_datetime" => "2026-01-01T00:00:00Z",
            "to_datetime" => "2026-01-31T23:59:59Z"
          }
        )
      end

      it "returns the billing period from fee properties" do
        period = helper.billing_period_for(fee, invoice_subscription:)

        expect(period.from_datetime.to_date).to eq(Date.new(2026, 1, 1))
        expect(period.to_datetime.to_date).to eq(Date.new(2026, 1, 31))
      end
    end

    context "when fee has missing properties" do
      let(:fee) do
        create(
          :fee,
          fee_type: :subscription,
          subscription:,
          invoice:,
          properties: {}
        )
      end

      it "falls back to invoice_subscription boundaries" do
        period = helper.billing_period_for(fee, invoice_subscription:)

        expect(period.from_datetime).to eq(invoice_subscription.from_datetime)
        expect(period.to_datetime).to eq(invoice_subscription.to_datetime)
      end
    end

    context "when fee has a different type" do
      let(:fee) do
        create(
          :fee,
          fee_type: :add_on,
          invoice:,
          properties: {}
        )
      end

      it "falls back to invoice_subscription boundaries" do
        period = helper.billing_period_for(fee, invoice_subscription:)

        expect(period.from_datetime).to eq(invoice_subscription.from_datetime)
        expect(period.to_datetime).to eq(invoice_subscription.to_datetime)
      end
    end

    context "when fee is a recurring pay-in-advance charge (reconciliation fee)" do
      # This tests the scenario where:
      # - Plan is pay-in-arrears
      # - Charge is pay-in-advance with a recurring billable metric
      # - Fee has pay_in_advance: false (reconciliation fee, not instant fee)
      # - Fee properties have charges_from_datetime matching the arrears period
      # - But the billing period should show the pay-in-advance interval (next period)
      let(:calendar_subscription) do
        create(
          :subscription,
          customer:,
          plan:,
          billing_time: :calendar,
          subscription_at: DateTime.parse("2025-12-01T00:00:00"),
          started_at: DateTime.parse("2025-12-01T00:00:00")
        )
      end
      let(:calendar_invoice_subscription) do
        create(
          :invoice_subscription,
          subscription: calendar_subscription,
          invoice:,
          from_datetime: DateTime.parse("2025-12-01T00:00:00"),
          to_datetime: DateTime.parse("2025-12-31T23:59:59"),
          charges_from_datetime: DateTime.parse("2025-12-01T00:00:00"),
          charges_to_datetime: DateTime.parse("2025-12-31T23:59:59"),
          timestamp: DateTime.parse("2026-01-01T00:00:00")
        )
      end
      let(:recurring_billable_metric) { create(:sum_billable_metric, organization:, recurring: true) }
      let(:pay_in_advance_charge) do
        create(:standard_charge, :pay_in_advance, plan:, billable_metric: recurring_billable_metric)
      end

      # Reconciliation fee: fee.pay_in_advance = false, charge.pay_in_advance = true
      # Properties store the arrears period (December), but should display as January
      let(:reconciliation_fee) do
        create(
          :charge_fee,
          charge: pay_in_advance_charge,
          subscription: calendar_subscription,
          invoice:,
          pay_in_advance: false,
          properties: {
            "charges_from_datetime" => "2025-12-01T00:00:00Z",
            "charges_to_datetime" => "2025-12-31T23:59:59Z"
          }
        )
      end

      it "returns the pay-in-advance interval (next period), not the stored properties" do
        period = helper.billing_period_for(reconciliation_fee, invoice_subscription: calendar_invoice_subscription)

        # The fee properties say December, but since this is a reconciliation fee
        # for a pay-in-advance charge on an arrears plan, it should show January
        # (the period that was paid in advance)
        expect(period.from_datetime.to_date).to eq(Date.new(2026, 1, 1))
        expect(period.to_datetime.to_date).to eq(Date.new(2026, 1, 31))
      end
    end
  end

  describe ".format_billing_period" do
    let(:billing_period) do
      described_class::BillingPeriod.new(
        from_datetime: DateTime.parse("2025-12-01T00:00:00"),
        to_datetime: DateTime.parse("2025-12-31T23:59:59")
      )
    end

    it "formats the billing period using I18n" do
      result = helper.format_billing_period(billing_period, customer:)

      expect(result).to eq "Fees from Dec 01, 2025 to Dec 31, 2025"
    end
  end

  describe "BillingPeriod" do
    describe "#to_grouping_key" do
      it "returns an array of dates for grouping" do
        period = described_class::BillingPeriod.new(
          from_datetime: DateTime.parse("2025-12-01T00:00:00"),
          to_datetime: DateTime.parse("2025-12-31T23:59:59")
        )

        expect(period.to_grouping_key).to eq([Date.new(2025, 12, 1), Date.new(2025, 12, 31)])
      end
    end

    describe "#==" do
      it "considers two periods with same dates as equal" do
        period1 = described_class::BillingPeriod.new(
          from_datetime: DateTime.parse("2025-12-01T00:00:00"),
          to_datetime: DateTime.parse("2025-12-31T23:59:59")
        )
        period2 = described_class::BillingPeriod.new(
          from_datetime: DateTime.parse("2025-12-01T12:00:00"),
          to_datetime: DateTime.parse("2025-12-31T12:00:00")
        )

        expect(period1).to eq(period2)
      end

      context "when periods have different times" do
        it "considers two periods with same dates but different times as equal" do
          period1 = described_class::BillingPeriod.new(
            from_datetime: DateTime.parse("2025-12-01T00:00:00"),
            to_datetime: DateTime.parse("2025-12-31T23:59:59")
          )

          period2 = described_class::BillingPeriod.new(
            from_datetime: DateTime.parse("2025-12-01T00:00:00"),
            to_datetime: DateTime.parse("2025-12-31T23:59:59")
          )

          expect(period1).to eq(period2)
        end
      end

      context "when periods have different dates" do
        it "considers two periods with different dates as not equal" do
          period1 = described_class::BillingPeriod.new(
            from_datetime: DateTime.parse("2025-12-01T00:00:00"),
            to_datetime: DateTime.parse("2025-12-31T23:59:59")
          )
          period2 = described_class::BillingPeriod.new(
            from_datetime: DateTime.parse("2025-12-02T00:00:00"),
            to_datetime: DateTime.parse("2025-12-31T23:59:59")
          )

          expect(period1).not_to eq(period2)
        end
      end
    end
  end

  describe "GroupedFees" do
    describe "#has_any_fees?" do
      it "returns true when subscription fee is present" do
        grouped = described_class::GroupedFees.new(
          billing_period: described_class::BillingPeriod.new(from_datetime: Time.current, to_datetime: Time.current),
          subscription_fee: build(:fee),
          fixed_charge_fees: [],
          charge_fees: [],
          commitment_fee: nil
        )

        expect(grouped.has_any_fees?).to be true
      end

      it "returns true when charge fees are present" do
        grouped = described_class::GroupedFees.new(
          billing_period: described_class::BillingPeriod.new(from_datetime: Time.current, to_datetime: Time.current),
          subscription_fee: nil,
          fixed_charge_fees: [],
          charge_fees: [build(:fee)],
          commitment_fee: nil
        )

        expect(grouped.has_any_fees?).to be true
      end

      it "returns true when fixed charge fees are present" do
        grouped = described_class::GroupedFees.new(
          billing_period: described_class::BillingPeriod.new(from_datetime: Time.current, to_datetime: Time.current),
          subscription_fee: nil,
          fixed_charge_fees: [build(:fee)],
          charge_fees: [],
          commitment_fee: nil
        )

        expect(grouped.has_any_fees?).to be true
      end

      it "returns true when minimum commitment fees are present" do
        grouped = described_class::GroupedFees.new(
          billing_period: described_class::BillingPeriod.new(from_datetime: Time.current, to_datetime: Time.current),
          subscription_fee: nil,
          fixed_charge_fees: [],
          charge_fees: [],
          commitment_fee: build(:fee)
        )

        expect(grouped.has_any_fees?).to be true
      end

      it "returns false when no fees are present" do
        grouped = described_class::GroupedFees.new(
          billing_period: described_class::BillingPeriod.new(from_datetime: Time.current, to_datetime: Time.current),
          subscription_fee: nil,
          fixed_charge_fees: [],
          charge_fees: [],
          commitment_fee: nil
        )

        expect(grouped.has_any_fees?).to be false
      end
    end
  end
end
