# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningCampaigns::BulkProcessService do
  subject(:result) { described_class.call }

  let(:currency) { "EUR" }

  context "when premium features are enabled", :premium do
    let(:organization) { create :organization, premium_integrations: %w[auto_dunning] }
    let(:billing_entity) { organization.default_billing_entity }
    let(:customer) { create :customer, organization:, billing_entity:, currency: }

    let(:invoice_1) do
      create(
        :invoice,
        organization:,
        customer:,
        currency:,
        payment_overdue: true,
        total_amount_cents: 50_00
      )
    end

    let(:invoice_2) do
      create(
        :invoice,
        organization:,
        customer:,
        currency:,
        payment_overdue: true,
        total_amount_cents: 1_00
      )
    end

    context "when billing_entity has an applied dunning campaign" do
      let(:dunning_campaign) { create :dunning_campaign, organization: }

      let(:dunning_campaign_threshold) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign:,
          currency:,
          amount_cents: 50_99
        )
      end

      before do
        dunning_campaign
        dunning_campaign_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
      end

      context "when a customer has overdue balance exceeding threshold in same currency" do
        before do
          invoice_1
          invoice_2
        end

        it "enqueues an ProcessAttemptJob with the customer and threshold" do
          expect(result).to be_success
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued
            .with(customer:, dunning_campaign_threshold:, billing_entity:)
        end

        it "increments the per-currency attempt counter" do
          freeze_time do
            expect { result && customer.reload }
              .to change { customer.dunning_currency_attempts[currency] }.from(nil).to(1)
              .and change(customer, :last_dunning_campaign_attempt_at).to(Time.zone.now)
          end
        end

        context "when organization does not have auto_dunning feature enabled" do
          let(:organization) { create(:organization, premium_integrations: []) }

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end

        context "when maximum attempts are reached for the currency" do
          let(:customer) do
            create :customer, organization:, billing_entity:,
              dunning_currency_attempts: {currency => 5}
          end

          let(:dunning_campaign) do
            create(
              :dunning_campaign,
              organization:,
              max_attempts: 5
            )
          end

          before { billing_entity.update!(applied_dunning_campaign: dunning_campaign) }

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end

        context "when not enough days have passed since last attempt" do
          let(:customer) { create :customer, organization:, billing_entity:, last_dunning_campaign_attempt_at: 3.days.ago }

          let(:dunning_campaign) do
            create(
              :dunning_campaign,
              organization:,
              days_between_attempts: 4
            )
          end

          before { billing_entity.update!(applied_dunning_campaign: dunning_campaign) }

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end

        context "when enough days have passed since last attempt" do
          let(:customer) { create :customer, organization:, billing_entity:, last_dunning_campaign_attempt_at: 4.days.ago - 1.second }

          let(:dunning_campaign) do
            create(
              :dunning_campaign,
              organization:,
              days_between_attempts: 4
            )
          end

          before { billing_entity.update!(applied_dunning_campaign: dunning_campaign) }

          it "enqueues an ProcessAttemptJob with the customer and threshold" do
            expect(result).to be_success
            expect(DunningCampaigns::ProcessAttemptJob)
              .to have_been_enqueued
              .with(customer:, dunning_campaign_threshold:, billing_entity:)
          end
        end
      end

      context "when customer has overdue balance below threshold" do
        before do
          invoice_1
        end

        it "does not queue a job for the customer" do
          result
          expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
        end
      end

      context "when there is no matching threshold for customer overdue balance" do
        let(:dunning_campaign_threshold) do
          create(
            :dunning_campaign_threshold,
            dunning_campaign:,
            currency: "GBP",
            amount_cents: 1
          )
        end

        before do
          invoice_1
        end

        it "does not queue a job for the customer" do
          result
          expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
        end
      end

      context "when customer has an applied dunning campaign overwriting billing entity's default campaign" do
        let(:customer) do
          create(
            :customer,
            organization:,
            billing_entity:,
            currency:,
            applied_dunning_campaign: customer_dunning_campaign
          )
        end

        let(:customer_dunning_campaign) do
          create(:dunning_campaign, organization:)
        end

        let(:customer_dunning_campaign_threshold) do
          create(
            :dunning_campaign_threshold,
            dunning_campaign: customer_dunning_campaign,
            currency:,
            amount_cents: 49_99
          )
        end

        before do
          customer_dunning_campaign
          customer_dunning_campaign_threshold
        end

        context "when a customer has overdue balance exceeding threshold in same currency" do
          before do
            invoice_1
          end

          it "enqueues an ProcessAttemptJob with the customer and customer's campaign threshold" do
            expect(result).to be_success
            expect(DunningCampaigns::ProcessAttemptJob)
              .to have_been_enqueued
              .with(customer:, dunning_campaign_threshold: customer_dunning_campaign_threshold, billing_entity:)
          end
        end

        context "when customer has overdue balance below threshold" do
          before do
            invoice_2
          end

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end

        context "when there is no matching threshold for customer overdue balance" do
          let(:customer_dunning_campaign_threshold) do
            create(
              :dunning_campaign_threshold,
              dunning_campaign:,
              currency: "GBP",
              amount_cents: 1
            )
          end

          before do
            invoice_1
          end

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end
      end

      context "when customer is excluded from dunning campaigns" do
        let(:customer) { create :customer, organization:, billing_entity:, currency:, exclude_from_dunning_campaign: true }

        context "when a customer has overdue balance exceeding threshold in same currency" do
          before do
            invoice_1
            invoice_2
          end

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end
      end

      context "when customer has no overdue invoices" do
        let(:customer_without_overdue) { create :customer, organization:, billing_entity:, currency: }

        before do
          create(:invoice, organization:, customer: customer_without_overdue, currency:, payment_overdue: false, total_amount_cents: 100_00)
          create(:invoice, organization:, customer:, currency:, payment_overdue: true, total_amount_cents: 51_00)
        end

        it "excludes customer without overdue invoices from eligible customers" do
          eligible = described_class.new.send(:eligible_customers)

          expect(eligible).to include(customer)
          expect(eligible).not_to include(customer_without_overdue)
        end
      end
    end

    context "when customer has an applied dunning campaign" do
      let(:customer) do
        create(
          :customer,
          organization:,
          billing_entity:,
          currency:,
          applied_dunning_campaign: dunning_campaign
        )
      end

      let(:dunning_campaign) do
        create(:dunning_campaign, organization:)
      end

      let(:dunning_campaign_threshold) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign:,
          currency:,
          amount_cents: 49_99
        )
      end

      before do
        dunning_campaign
        dunning_campaign_threshold
      end

      context "when a customer has overdue balance exceeding threshold in same currency" do
        before do
          invoice_1
        end

        it "enqueues an ProcessAttemptJob with the customer and customer's campaign threshold" do
          expect(result).to be_success
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued
            .with(customer:, dunning_campaign_threshold:, billing_entity:)
        end

        context "when organization does not have auto_dunning feature enabled" do
          let(:organization) { create(:organization, premium_integrations: []) }

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end

        context "when maximum attempts are reached for the currency" do
          let(:customer) do
            create :customer, organization:, billing_entity:,
              dunning_currency_attempts: {currency => 5}
          end

          let(:dunning_campaign) do
            create(
              :dunning_campaign,
              organization:,
              max_attempts: 5
            )
          end

          before { billing_entity.update!(applied_dunning_campaign: dunning_campaign) }

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end

        context "when not enough days have passed since last attempt" do
          let(:customer) { create :customer, organization:, billing_entity:, last_dunning_campaign_attempt_at: 3.days.ago }

          let(:dunning_campaign) do
            create(
              :dunning_campaign,
              organization:,
              days_between_attempts: 4
            )
          end

          before { billing_entity.update!(applied_dunning_campaign: dunning_campaign) }

          it "does not queue a job for the customer" do
            result
            expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
          end
        end

        context "when enough days have passed since last attempt" do
          let(:customer) { create :customer, organization:, billing_entity:, last_dunning_campaign_attempt_at: 4.days.ago - 1.second }

          let(:dunning_campaign) do
            create(
              :dunning_campaign,
              organization:,
              days_between_attempts: 4
            )
          end

          before { billing_entity.update!(applied_dunning_campaign: dunning_campaign) }

          it "enqueues an ProcessAttemptJob with the customer and threshold" do
            expect(result).to be_success
            expect(DunningCampaigns::ProcessAttemptJob)
              .to have_been_enqueued
              .with(customer:, dunning_campaign_threshold:, billing_entity:)
          end
        end
      end

      context "when customer has overdue balance below threshold" do
        before do
          invoice_2
        end

        it "does not queue a job for the customer" do
          result
          expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
        end
      end

      context "when there is no matching threshold for customer overdue balance" do
        let(:dunning_campaign_threshold) do
          create(
            :dunning_campaign_threshold,
            dunning_campaign:,
            currency: "GBP",
            amount_cents: 1
          )
        end

        before do
          invoice_1
        end

        it "does not queue a job for the customer" do
          result
          expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
        end
      end
    end

    context "when neither billing_entity nor customer has an applied dunning campaign" do
      let(:dunning_campaign) { create :dunning_campaign, organization: }

      let(:dunning_campaign_threshold) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign:,
          currency:,
          amount_cents: 1
        )
      end

      before do
        dunning_campaign_threshold
        invoice_1
      end

      it "does not queue a job for the customer" do
        result
        expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
      end
    end

    context "when customer has overdue invoices in multiple currencies" do
      let(:dunning_campaign) { create :dunning_campaign, organization: }

      let(:usd_threshold) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign:,
          currency: "USD",
          amount_cents: 40_00
        )
      end

      let(:eur_threshold) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign:,
          currency: "EUR",
          amount_cents: 20_00
        )
      end

      let(:customer) { create :customer, organization:, billing_entity:, currency: "USD" }

      before do
        usd_threshold
        eur_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
      end

      context "when both currencies exceed their thresholds" do
        before do
          create(:invoice, organization:, customer:, currency: "USD", payment_overdue: true, total_amount_cents: 50_00)
          create(:invoice, organization:, customer:, currency: "EUR", payment_overdue: true, total_amount_cents: 25_00)
        end

        it "enqueues a ProcessAttemptJob for each currency" do
          result
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued.with(customer:, dunning_campaign_threshold: usd_threshold, billing_entity:)
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued.with(customer:, dunning_campaign_threshold: eur_threshold, billing_entity:)
        end

        it "increments per-currency counters independently" do
          result
          customer.reload
          expect(customer.dunning_currency_attempts).to eq("USD" => 1, "EUR" => 1)
        end
      end

      context "when only one currency exceeds its threshold" do
        before do
          create(:invoice, organization:, customer:, currency: "USD", payment_overdue: true, total_amount_cents: 50_00)
          create(:invoice, organization:, customer:, currency: "EUR", payment_overdue: true, total_amount_cents: 15_00)
        end

        it "enqueues a ProcessAttemptJob only for the matching currency" do
          result
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued.with(customer:, dunning_campaign_threshold: usd_threshold, billing_entity:)
          expect(DunningCampaigns::ProcessAttemptJob)
            .not_to have_been_enqueued.with(customer:, dunning_campaign_threshold: eur_threshold, billing_entity:)
        end
      end

      context "when overdue invoices exist in a currency without a threshold" do
        before do
          create(:invoice, organization:, customer:, currency: "USD", payment_overdue: true, total_amount_cents: 50_00)
          create(:invoice, organization:, customer:, currency: "GBP", payment_overdue: true, total_amount_cents: 100_00)
        end

        it "only enqueues for currencies with matching thresholds" do
          result
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued.with(customer:, dunning_campaign_threshold: usd_threshold, billing_entity:)
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued.once
        end
      end
    end

    context "when organization has multiple billing entities with different applied dunning campaigns" do
      let(:billing_entity_1) { create :billing_entity, organization:, applied_dunning_campaign: dunning_campaign_1 }
      let(:billing_entity_2) { create :billing_entity, organization:, applied_dunning_campaign: dunning_campaign_2 }
      let(:customer_1) { create :customer, organization:, billing_entity: billing_entity_1, currency: }
      let(:customer_2) { create :customer, organization:, billing_entity: billing_entity_2, currency: }
      let(:customer_3) { create :customer, organization:, billing_entity: billing_entity, currency:, applied_dunning_campaign: dunning_campaign_1 }

      let(:dunning_campaign_1) { create :dunning_campaign, organization: }
      let(:dunning_campaign_2) { create :dunning_campaign, organization: }

      let(:dunning_campaign_threshold_1) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign: dunning_campaign_1,
          currency:,
          amount_cents: 50_99
        )
      end

      let(:dunning_campaign_threshold_2) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign: dunning_campaign_2,
          currency:,
          amount_cents: 49_99
        )
      end

      before do
        dunning_campaign_threshold_1
        dunning_campaign_threshold_2
      end

      context "when all customers have overdue balances exceeding all thresholds" do
        before do
          create(:invoice, organization:, customer:, billing_entity:, currency:, payment_overdue: true, total_amount_cents: 100_00)
          create(:invoice, organization:, customer: customer_1, billing_entity: billing_entity_1, currency:, payment_overdue: true, total_amount_cents: 60_00)
          create(:invoice, organization:, customer: customer_2, billing_entity: billing_entity_2, currency:, payment_overdue: true, total_amount_cents: 51_00)
          create(:invoice, organization:, customer: customer_3, billing_entity:, currency:, payment_overdue: true, total_amount_cents: 51_00)
        end

        it "enqueues ProcessAttemptJob for both customers with their respective thresholds" do
          expect(result).to be_success
          expect(DunningCampaigns::ProcessAttemptJob)
            .not_to have_been_enqueued.with(hash_including(customer: customer))
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued.with(customer: customer_1, dunning_campaign_threshold: dunning_campaign_threshold_1, billing_entity: billing_entity_1)
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued.with(customer: customer_2, dunning_campaign_threshold: dunning_campaign_threshold_2, billing_entity: billing_entity_2)
          expect(DunningCampaigns::ProcessAttemptJob)
            .to have_been_enqueued.with(customer: customer_3, dunning_campaign_threshold: dunning_campaign_threshold_1, billing_entity:)
        end
      end
    end

    context "when maximum attempts are reached for the currency" do
      let(:dunning_campaign) do
        create(
          :dunning_campaign,
          organization:,
          max_attempts: 3,
          days_between_attempts: 5
        )
      end

      let(:dunning_campaign_threshold) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign:,
          currency:,
          amount_cents: 500
        )
      end

      let(:customer) do
        create :customer,
          organization:,
          billing_entity:,
          currency:,
          dunning_currency_attempts: {currency => 3},
          last_dunning_campaign_attempt_at:
      end

      before do
        dunning_campaign_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
        create(:invoice, organization:, customer:, currency:, payment_overdue: true, total_amount_cents: 600)
      end

      context "when not enough days have passed since last attempt" do
        let(:last_dunning_campaign_attempt_at) { 3.days.ago }

        it "does not send the campaign finished webhook" do
          result
          expect(SendWebhookJob).not_to have_been_enqueued
        end

        it "does not enqueue a process attempt job" do
          result
          expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
        end
      end

      context "when enough days have passed since last attempt" do
        let(:last_dunning_campaign_attempt_at) { 6.days.ago }

        it "does not enqueue a process attempt job" do
          result
          expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
        end
      end
    end

    context "when max attempts reached after processing sends finished webhook" do
      let(:dunning_campaign) do
        create(
          :dunning_campaign,
          organization:,
          max_attempts: 1
        )
      end

      let(:dunning_campaign_threshold) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign:,
          currency:,
          amount_cents: 500
        )
      end

      before do
        dunning_campaign_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
        create(:invoice, organization:, customer:, currency:, payment_overdue: true, total_amount_cents: 600)
      end

      it "sends the campaign finished webhook" do
        expect { result }.to have_enqueued_job(SendWebhookJob)
          .with("dunning_campaign.finished", customer, {dunning_campaign_code: dunning_campaign.code})
      end

      it "still enqueues the process attempt job" do
        result
        expect(DunningCampaigns::ProcessAttemptJob)
          .to have_been_enqueued.with(customer:, dunning_campaign_threshold:, billing_entity:)
      end
    end

    context "when one currency is maxed but another is not" do
      let(:dunning_campaign) { create :dunning_campaign, organization:, max_attempts: 2 }

      let(:usd_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency: "USD", amount_cents: 40_00)
      end

      let(:eur_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency: "EUR", amount_cents: 20_00)
      end

      let(:customer) do
        create :customer, organization:, billing_entity:, currency: "USD",
          dunning_currency_attempts: {"USD" => 2}
      end

      before do
        usd_threshold
        eur_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
        create(:invoice, organization:, customer:, currency: "USD", payment_overdue: true, total_amount_cents: 50_00)
        create(:invoice, organization:, customer:, currency: "EUR", payment_overdue: true, total_amount_cents: 25_00)
      end

      it "only enqueues for the currency that has not reached max attempts" do
        result
        expect(DunningCampaigns::ProcessAttemptJob)
          .not_to have_been_enqueued.with(customer:, dunning_campaign_threshold: usd_threshold, billing_entity:)
        expect(DunningCampaigns::ProcessAttemptJob)
          .to have_been_enqueued.with(customer:, dunning_campaign_threshold: eur_threshold, billing_entity:)
      end

      it "only increments the non-maxed currency counter" do
        result
        customer.reload
        expect(customer.dunning_currency_attempts["USD"]).to eq(2)
        expect(customer.dunning_currency_attempts["EUR"]).to eq(1)
      end

      it "does not send the campaign finished webhook" do
        result
        expect(SendWebhookJob).not_to have_been_enqueued
      end
    end

    context "when one currency is maxed and another has overdue below threshold" do
      let(:dunning_campaign) { create :dunning_campaign, organization:, max_attempts: 3, days_between_attempts: 1 }

      let(:usd_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency: "USD", amount_cents: 40_00)
      end

      let(:eur_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency: "EUR", amount_cents: 80_00)
      end

      let(:customer) do
        create :customer, organization:, billing_entity:, currency: "USD",
          dunning_currency_attempts: {"USD" => 3},
          last_dunning_campaign_attempt_at: 2.days.ago
      end

      before do
        usd_threshold
        eur_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
        create(:invoice, organization:, customer:, currency: "USD", payment_overdue: true, total_amount_cents: 50_00)
        create(:invoice, organization:, customer:, currency: "EUR", payment_overdue: true, total_amount_cents: 52_07)
      end

      it "does not send the campaign finished webhook" do
        result
        expect(SendWebhookJob).not_to have_been_enqueued
      end

      it "does not enqueue any process attempt job" do
        result
        expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
      end

      it "does not modify dunning currency attempts" do
        expect { result }.not_to change { customer.reload.dunning_currency_attempts }
      end
    end

    context "when one currency is maxed and another has no overdue at all" do
      let(:dunning_campaign) { create :dunning_campaign, organization:, max_attempts: 2, days_between_attempts: 1 }

      let(:usd_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency: "USD", amount_cents: 40_00)
      end

      let(:eur_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency: "EUR", amount_cents: 20_00)
      end

      let(:customer) do
        create :customer, organization:, billing_entity:, currency: "USD",
          dunning_currency_attempts: {"USD" => 2},
          last_dunning_campaign_attempt_at: 2.days.ago
      end

      before do
        usd_threshold
        eur_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
        create(:invoice, organization:, customer:, currency: "USD", payment_overdue: true, total_amount_cents: 50_00)
      end

      it "does not send the campaign finished webhook" do
        result
        expect(SendWebhookJob).not_to have_been_enqueued
      end

      it "does not enqueue any process attempt job" do
        result
        expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
      end
    end

    context "when customer has overdue invoices across multiple billing entities" do
      let(:other_billing_entity) { create :billing_entity, organization: }
      let(:dunning_campaign) { create :dunning_campaign, organization:, max_attempts: 2 }
      let(:dunning_campaign_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency:, amount_cents: 40_00)
      end

      before do
        dunning_campaign_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
        create(:invoice, organization:, customer:, billing_entity:, currency:, payment_overdue: true, total_amount_cents: 50_00)
        create(:invoice, organization:, customer:, billing_entity: other_billing_entity, currency:, payment_overdue: true, total_amount_cents: 60_00)
      end

      it "enqueues one ProcessAttemptJob per billing entity carrying overdue invoices in the currency" do
        result
        expect(DunningCampaigns::ProcessAttemptJob)
          .to have_been_enqueued
          .with(customer:, dunning_campaign_threshold:, billing_entity:)
        expect(DunningCampaigns::ProcessAttemptJob)
          .to have_been_enqueued
          .with(customer:, dunning_campaign_threshold:, billing_entity: other_billing_entity)
        expect(DunningCampaigns::ProcessAttemptJob)
          .to have_been_enqueued.twice
      end

      it "increments the per-currency counter only once" do
        result
        customer.reload
        expect(customer.dunning_currency_attempts).to eq(currency => 1)
      end
    end

    context "when all currencies have reached max attempts" do
      let(:dunning_campaign) { create :dunning_campaign, organization:, max_attempts: 3, days_between_attempts: 1 }

      let(:usd_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency: "USD", amount_cents: 40_00)
      end

      let(:eur_threshold) do
        create(:dunning_campaign_threshold, dunning_campaign:, currency: "EUR", amount_cents: 80_00)
      end

      let(:customer) do
        create :customer, organization:, billing_entity:, currency: "USD",
          dunning_currency_attempts: {"USD" => 3, "EUR" => 3},
          last_dunning_campaign_attempt_at: 2.days.ago
      end

      before do
        usd_threshold
        eur_threshold
        billing_entity.update!(applied_dunning_campaign: dunning_campaign)
        create(:invoice, organization:, customer:, currency: "USD", payment_overdue: true, total_amount_cents: 50_00)
        create(:invoice, organization:, customer:, currency: "EUR", payment_overdue: true, total_amount_cents: 100_00)
      end

      it "does not send the campaign finished webhook again" do
        result
        expect(SendWebhookJob).not_to have_been_enqueued
      end

      it "does not enqueue any process attempt job" do
        result
        expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
      end
    end
  end

  it "does not queue jobs" do
    result
    expect(DunningCampaigns::ProcessAttemptJob).not_to have_been_enqueued
  end
end
