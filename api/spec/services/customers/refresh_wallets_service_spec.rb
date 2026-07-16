# frozen_string_literal: true

RSpec.describe Customers::RefreshWalletsService do
  describe "#call" do
    subject(:result) { described_class.call(customer:, include_generating_invoices:) }

    let(:include_generating_invoices) { false }
    let(:customer) { create(:customer, awaiting_wallet_refresh: true) }
    let(:organization) { customer.organization }
    let(:billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }
    let(:pay_in_advance_billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }

    let(:subscriptions) do
      [
        create(:subscription, organization:, customer:, started_at: Time.zone.now - 2.years),
        create(:subscription, organization:, customer:, started_at: Time.zone.now - 1.year)
      ]
    end

    before do
      create(
        :wallet,
        customer:,
        balance_cents: 1000,
        ongoing_balance_cents: 1000,
        ongoing_usage_balance_cents: 0,
        credits_balance: 10.0,
        credits_ongoing_balance: 10.0,
        credits_ongoing_usage_balance: 0
      )

      create(:wallet, :terminated, customer:)

      subscriptions.map do |subscription|
        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric:,
          properties: {amount: "3", presentation_group_keys: [{value: "cloud"}]}
        )

        create(
          :standard_charge,
          plan: subscription.plan,
          billable_metric: pay_in_advance_billable_metric,
          properties: {amount: "1", presentation_group_keys: [{value: "region"}]},
          pay_in_advance: true,
          invoiceable: true
        )
      end

      create_pair(
        :event,
        organization:,
        subscription: subscriptions.first,
        customer:,
        code: billable_metric.code
      )

      create(
        :event,
        organization:,
        subscription: subscriptions.second,
        customer:,
        code: billable_metric.code
      )

      create(
        :event,
        organization:,
        subscription: subscriptions.second,
        customer:,
        code: pay_in_advance_billable_metric.code
      )
    end

    it "calls Wallets::Balance::RefreshOngoingUsageService for each active wallet" do
      allow(Wallets::Balance::RefreshOngoingUsageService).to receive(:call!).and_call_original

      subject

      expect(Wallets::Balance::RefreshOngoingUsageService)
        .to have_received(:call!)
        .exactly(customer.wallets.active.count).times
    end

    it "refreshes the wallet balances" do
      expect(result).to be_success
      expect(result.wallets).to match_array(customer.wallets.active)

      wallet = result.wallets.first
      expect(wallet.ongoing_usage_balance_cents).to eq 900
      expect(wallet.credits_ongoing_usage_balance).to eq 9.0
      expect(wallet.ongoing_balance_cents).to eq 100
      expect(wallet.credits_ongoing_balance).to eq 1.0
    end

    it "marks customer as not awaiting wallet refresh" do
      expect { subject }.to change(customer, :awaiting_wallet_refresh).from(true).to(false)
    end

    context "when charges have presentation_group_keys" do
      before do
        allow(Invoices::CustomerUsageService).to receive(:call!).and_call_original
        allow(BillableMetrics::AggregationFactory).to receive(:new_instance).and_call_original
      end

      it "calls CustomerUsageService with UsageFilters::WITHOUT_PRESENTATION_FILTER" do
        subject

        customer.active_subscriptions.each do |subscription|
          expect(Invoices::CustomerUsageService).to have_received(:call!).with(
            customer:,
            subscription:,
            usage_filters: UsageFilters::WITHOUT_PRESENTATION_FILTER
          )
        end
      end

      it "calls AggregationFactory with presentation_by as empty array" do
        subject

        expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).at_least(:once) do |args|
          next unless args[:filters].key?(:presentation_by)

          expect(args[:filters][:presentation_by]).to eq([])
        end
      end
    end

    describe "current usage calculation" do
      let(:charges_to_datetime) { 1.week.from_now }
      let(:charges_from_datetime) { 1.week.ago }

      before do
        subscriptions.each do |subscription|
          create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) do |invoice_subscription|
            create(
              :charge_fee,
              subscription:,
              precise_coupons_amount_cents: 0,
              invoice: invoice_subscription.invoice,
              amount_cents: 100,
              taxes_amount_cents: 10
            )

            invoice_subscription.invoice.update!(
              invoice_type: :progressive_billing,
              fees_amount_cents: 110,
              total_amount_cents: 110,
              status: :generating
            )
          end
        end
      end

      context "when generating invoices are included" do
        let(:include_generating_invoices) { true }

        it "returns current usage for customer including generating invoices" do
          expect(result).to be_success

          wallet = result.wallets.first
          expect(wallet.ongoing_usage_balance_cents).to eq 680
          expect(wallet.credits_ongoing_usage_balance).to eq 6.8
          expect(wallet.ongoing_balance_cents).to eq 320
          expect(wallet.credits_ongoing_balance).to eq 3.2
        end
      end

      context "when generating invoices are excluded" do
        let(:include_generating_invoices) { false }

        it "returns current usage for customer excluding generating invoices" do
          expect(result).to be_success

          wallet = result.wallets.first
          expect(wallet.ongoing_usage_balance_cents).to eq 900
          expect(wallet.credits_ongoing_usage_balance).to eq 9.0
          expect(wallet.ongoing_balance_cents).to eq 100
          expect(wallet.credits_ongoing_balance).to eq 1.0
        end
      end
    end

    context "when failed to calculate current usage" do
      before do
        create(:anrok_customer, customer:)

        allow(Integrations::Aggregator::Taxes::Invoices::CreateDraftService)
          .to receive(:call)
          .and_return(
            BaseService::Result.new.service_failure!(
              code: "customerAddressCouldNotResolve",
              message: "Customer address could not resolve"
            )
          )
      end

      it "fails with an error" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:tax_error]).to eq(["customerAddressCouldNotResolve: Customer address could not resolve"])
      end
    end

    context "when target_wallet_ids is provided" do
      subject(:result) { described_class.call(customer:, include_generating_invoices:, target_wallet_ids: [target_wallet.id]) }

      let!(:target_wallet) do
        create(
          :wallet,
          customer:,
          balance_cents: 1000,
          ongoing_balance_cents: 1000,
          ongoing_usage_balance_cents: 0,
          credits_balance: 10.0,
          credits_ongoing_balance: 10.0,
          credits_ongoing_usage_balance: 0
        )
      end

      let!(:other_wallet) do
        create(
          :wallet,
          customer:,
          balance_cents: 2000,
          ongoing_balance_cents: 2000,
          ongoing_usage_balance_cents: 0,
          credits_balance: 20.0,
          credits_ongoing_balance: 20.0,
          credits_ongoing_usage_balance: 0
        )
      end

      it "only calls RefreshOngoingUsageService for targeted wallets" do
        allow(Wallets::Balance::RefreshOngoingUsageService).to receive(:call!).and_call_original

        subject

        expect(Wallets::Balance::RefreshOngoingUsageService)
          .to have_received(:call!).once
        expect(Wallets::Balance::RefreshOngoingUsageService)
          .to have_received(:call!).with(hash_including(wallet: target_wallet))
      end

      it "only updates last_ongoing_balance_sync_at for targeted wallets" do
        subject

        expect(target_wallet.reload.last_ongoing_balance_sync_at).not_to be_nil
        expect(other_wallet.reload.last_ongoing_balance_sync_at).to be_nil
      end

      it "returns all active wallets in the result" do
        expect(result).to be_success
        expect(result.wallets).to match_array(customer.wallets.active)
      end
    end

    context "when there are wallet billable metric limitations" do
      subject(:result) { described_class.call(customer: targeted_customer, include_generating_invoices: false) }

      let(:targeted_customer) { create(:customer, organization: targeted_org, awaiting_wallet_refresh: true) }
      let(:targeted_org) { create(:organization) }
      let(:billable_metric1) { create(:billable_metric, organization: targeted_org, aggregation_type: "count_agg") }
      let(:billable_metric2) { create(:billable_metric, organization: targeted_org, aggregation_type: "count_agg") }

      let(:targeted_subscription) { create(:subscription, organization: targeted_org, customer: targeted_customer, started_at: Time.zone.now - 1.year) }

      let(:charge1) do
        create(:standard_charge, plan: targeted_subscription.plan, billable_metric: billable_metric1, properties: {amount: "3"})
      end

      let(:charge2) do
        create(:standard_charge, plan: targeted_subscription.plan, billable_metric: billable_metric2, properties: {amount: "5"})
      end

      let(:targeted_wallet) do
        create(
          :wallet,
          customer: targeted_customer,
          balance_cents: 1000,
          ongoing_balance_cents: 1000,
          ongoing_usage_balance_cents: 0,
          credits_balance: 10.0,
          credits_ongoing_balance: 10.0,
          credits_ongoing_usage_balance: 0,
          priority: 1
        )
      end

      let(:unrestricted_wallet) do
        create(
          :wallet,
          customer: targeted_customer,
          balance_cents: 2000,
          ongoing_balance_cents: 2000,
          ongoing_usage_balance_cents: 0,
          credits_balance: 20.0,
          credits_ongoing_balance: 20.0,
          credits_ongoing_usage_balance: 0,
          priority: 2
        )
      end

      let(:wallet_target) { create(:wallet_target, wallet: targeted_wallet, billable_metric: billable_metric1, organization: targeted_org) }

      before do
        charge1
        charge2
        targeted_wallet
        unrestricted_wallet
        wallet_target

        # 2 events for billable_metric1 -> 2 * $3 = $6 = 600 cents
        create_list(:event, 2, organization: targeted_org, subscription: targeted_subscription, customer: targeted_customer, code: billable_metric1.code)

        # 1 event for billable_metric2 -> 1 * $5 = $5 = 500 cents
        create(:event, organization: targeted_org, subscription: targeted_subscription, customer: targeted_customer, code: billable_metric2.code)
      end

      it "only counts targeted billable metric fees for the targeted wallet" do
        expect(result).to be_success

        # targeted_wallet has wallet_target for billable_metric1 only
        # So it should only count fees for billable_metric1: 600 cents
        expect(targeted_wallet.reload.ongoing_usage_balance_cents).to eq(600)
        expect(targeted_wallet.credits_ongoing_usage_balance).to eq(6.0)
        expect(targeted_wallet.ongoing_balance_cents).to eq(400)
        expect(targeted_wallet.credits_ongoing_balance).to eq(4.0)
      end

      it "counts remaining fees for the unrestricted wallet" do
        expect(result).to be_success

        # unrestricted_wallet should count fees for billable_metric2: 500 cents
        # (billable_metric1 fees are already allocated to targeted_wallet)
        expect(unrestricted_wallet.reload.ongoing_usage_balance_cents).to eq(500)
        expect(unrestricted_wallet.credits_ongoing_usage_balance).to eq(5.0)
        expect(unrestricted_wallet.ongoing_balance_cents).to eq(1500)
        expect(unrestricted_wallet.credits_ongoing_balance).to eq(15.0)
      end
    end

    context "when customer has multi-currency subscriptions" do
      subject(:result) { described_class.call(customer: mc_customer, include_generating_invoices: false) }

      let(:mc_org) { create(:organization) }
      let(:mc_customer) { create(:customer, organization: mc_org, awaiting_wallet_refresh: true) }
      let(:mc_billable_metric) { create(:billable_metric, organization: mc_org, aggregation_type: "count_agg") }
      let(:mc_pia_billable_metric) { create(:billable_metric, organization: mc_org, aggregation_type: "count_agg") }

      let(:usd_plan) { create(:plan, organization: mc_org, amount_cents: 10_000, amount_currency: "USD") }
      let(:eur_plan) { create(:plan, organization: mc_org, amount_cents: 10_000, amount_currency: "EUR") }

      let(:usd_subscription) { create(:subscription, organization: mc_org, customer: mc_customer, plan: usd_plan, started_at: Time.zone.now - 1.year) }
      let(:eur_subscription) { create(:subscription, organization: mc_org, customer: mc_customer, plan: eur_plan, started_at: Time.zone.now - 1.year) }

      let!(:usd_wallet) do
        create(
          :wallet,
          customer: mc_customer,
          organization: mc_org,
          currency: "USD",
          balance_cents: 10_000,
          ongoing_balance_cents: 10_000,
          ongoing_usage_balance_cents: 0,
          credits_balance: 100.0,
          credits_ongoing_balance: 100.0,
          credits_ongoing_usage_balance: 0
        )
      end

      let!(:eur_wallet) do
        create(
          :wallet,
          customer: mc_customer,
          organization: mc_org,
          currency: "EUR",
          balance_cents: 10_000,
          ongoing_balance_cents: 10_000,
          ongoing_usage_balance_cents: 0,
          credits_balance: 100.0,
          credits_ongoing_balance: 100.0,
          credits_ongoing_usage_balance: 0
        )
      end

      before do
        # In-arrears charges
        create(:standard_charge, plan: usd_plan, billable_metric: mc_billable_metric, properties: {amount: "3"})
        create(:standard_charge, plan: eur_plan, billable_metric: mc_billable_metric, properties: {amount: "5"})

        # Pay-in-advance charges
        create(:standard_charge, plan: usd_plan, billable_metric: mc_pia_billable_metric, properties: {amount: "2"}, pay_in_advance: true, invoiceable: true)
        create(:standard_charge, plan: eur_plan, billable_metric: mc_pia_billable_metric, properties: {amount: "4"}, pay_in_advance: true, invoiceable: true)

        # 2 events for USD in-arrears -> 2 * $3 = 600 cents
        create_list(
          :event, 2,
          organization: mc_org,
          subscription: usd_subscription,
          customer: mc_customer,
          code: mc_billable_metric.code
        )

        # 3 events for EUR in-arrears -> 3 * €5 = 1500 cents
        create_list(
          :event, 3,
          organization: mc_org,
          subscription: eur_subscription,
          customer: mc_customer,
          code: mc_billable_metric.code
        )

        # 1 event for USD PIA -> 1 * $2 = 200 cents (included in total usage, subtracted as billed)
        create(
          :event,
          organization: mc_org,
          subscription: usd_subscription,
          customer: mc_customer,
          code: mc_pia_billable_metric.code
        )

        # 1 event for EUR PIA -> 1 * €4 = 400 cents (included in total usage, subtracted as billed)
        create(
          :event,
          organization: mc_org,
          subscription: eur_subscription,
          customer: mc_customer,
          code: mc_pia_billable_metric.code
        )
      end

      it "calculates ongoing balance separately per currency" do
        expect(result).to be_success

        # USD: in-arrears 600 + PIA 200 = 800 total usage, minus 200 PIA billed = 600 ongoing usage
        expect(usd_wallet.reload.ongoing_usage_balance_cents).to eq(600)
        expect(usd_wallet.ongoing_balance_cents).to eq(9400)

        # EUR: in-arrears 1500 + PIA 400 = 1900 total usage, minus 400 PIA billed = 1500 ongoing usage
        expect(eur_wallet.reload.ongoing_usage_balance_cents).to eq(1500)
        expect(eur_wallet.ongoing_balance_cents).to eq(8500)
      end
    end
  end
end
