# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::GrossRevenue do
  describe ".cache_key" do
    subject(:gross_revenue_cache_key) { described_class.cache_key(organization_id, **args) }

    let(:organization_id) { SecureRandom.uuid }
    let(:billing_entity_id) { SecureRandom.uuid }
    let(:external_customer_id) { "customer_01" }
    let(:currency) { "EUR" }
    let(:months) { 12 }
    let(:date) { Date.current.strftime("%Y-%m-%d") }

    context "with no arguments" do
      let(:args) { {} }
      let(:cache_key) { "gross-revenue/#{date}/#{organization_id}////" }

      it "returns the cache key" do
        expect(gross_revenue_cache_key).to eq(cache_key)
      end
    end

    context "with customer external id, currency and months" do
      let(:args) { {external_customer_id:, currency:, months:} }

      let(:cache_key) do
        "gross-revenue/#{date}/#{organization_id}//#{external_customer_id}/#{currency}/#{months}"
      end

      it "returns the cache key" do
        expect(gross_revenue_cache_key).to eq(cache_key)
      end

      context "with billing entity id" do
        let(:args) { {external_customer_id:, currency:, months:, billing_entity_id:} }
        let(:cache_key) do
          "gross-revenue/#{date}/#{organization_id}/#{billing_entity_id}/#{external_customer_id}/#{currency}/#{months}"
        end

        it "returns the cache key" do
          expect(gross_revenue_cache_key).to eq(cache_key)
        end
      end
    end

    context "with customer external id" do
      let(:args) { {external_customer_id:} }

      let(:cache_key) do
        "gross-revenue/#{date}/#{organization_id}//#{external_customer_id}//"
      end

      it "returns the cache key" do
        expect(gross_revenue_cache_key).to eq(cache_key)
      end
    end

    context "with currency" do
      let(:args) { {currency:} }
      let(:cache_key) { "gross-revenue/#{date}/#{organization_id}///#{currency}/" }

      it "returns the cache key" do
        expect(gross_revenue_cache_key).to eq(cache_key)
      end
    end

    context "with billing entity id" do
      let(:args) { {billing_entity_id:} }
      let(:cache_key) { "gross-revenue/#{date}/#{organization_id}/#{billing_entity_id}///" }

      it "returns the cache key" do
        expect(gross_revenue_cache_key).to eq(cache_key)
      end
    end
  end

  describe ".find_all_by" do
    subject(:gross_revenues) { described_class.find_all_by(organization.id, **args) }

    let(:organization) { create(:organization, created_at: 3.months.ago) }
    let(:billing_entity1) { organization.default_billing_entity }
    let(:billing_entity2) { create(:billing_entity, organization: organization) }
    let(:invoices) {
      [
        create(:invoice, organization:, total_amount_cents: 1000, issuing_date: 1.month.ago, billing_entity: billing_entity1),
        create(:invoice, organization:, total_amount_cents: 2000, issuing_date: 1.month.ago, billing_entity: billing_entity2),
        create(:invoice, organization:, total_amount_cents: 3000, issuing_date: 2.months.ago, billing_entity: billing_entity1),
        create(:invoice, organization:, total_amount_cents: 4000, issuing_date: 2.months.ago, billing_entity: billing_entity2)
      ]
    }

    before { invoices }

    context "when no filters passed" do
      let(:args) { {} }

      it "returns gross revenues split per (month, currency, billing_entity_id)" do
        expect(gross_revenues).to match_array([hash_including({
          "month" => Time.current.beginning_of_month - 2.months,
          "currency" => "EUR",
          "billing_entity_id" => billing_entity1.id,
          "invoices_count" => 1,
          "amount_cents" => 3000.0
        }), hash_including({
          "month" => Time.current.beginning_of_month - 2.months,
          "currency" => "EUR",
          "billing_entity_id" => billing_entity2.id,
          "invoices_count" => 1,
          "amount_cents" => 4000.0
        }), hash_including({
          "month" => Time.current.beginning_of_month - 1.month,
          "currency" => "EUR",
          "billing_entity_id" => billing_entity1.id,
          "invoices_count" => 1,
          "amount_cents" => 1000.0
        }), hash_including({
          "month" => Time.current.beginning_of_month - 1.month,
          "currency" => "EUR",
          "billing_entity_id" => billing_entity2.id,
          "invoices_count" => 1,
          "amount_cents" => 2000.0
        })])
      end

      context "when an organization has multiple billing entities with different currencies" do
        let(:invoices) {
          [
            create(:invoice, organization:, total_amount_cents: 1000, issuing_date: 1.month.ago, billing_entity: billing_entity1, currency: "USD"),
            create(:invoice, organization:, total_amount_cents: 2000, issuing_date: 1.month.ago, billing_entity: billing_entity2, currency: "EUR"),
            create(:invoice, organization:, total_amount_cents: 3000, issuing_date: 2.months.ago, billing_entity: billing_entity1, currency: "USD"),
            create(:invoice, organization:, total_amount_cents: 4000, issuing_date: 2.months.ago, billing_entity: billing_entity2, currency: "EUR")
          ]
        }

        it "returns gross revenues grouped by currencies and billing entities" do
          expect(gross_revenues).to match_array([hash_including({
            "month" => Time.current.beginning_of_month - 1.month,
            "currency" => "USD",
            "billing_entity_id" => billing_entity1.id,
            "invoices_count" => 1,
            "amount_cents" => 1000.0
          }), hash_including({
            "month" => Time.current.beginning_of_month - 1.month,
            "currency" => "EUR",
            "billing_entity_id" => billing_entity2.id,
            "invoices_count" => 1,
            "amount_cents" => 2000.0
          }), hash_including({
            "month" => Time.current.beginning_of_month - 2.months,
            "currency" => "USD",
            "billing_entity_id" => billing_entity1.id,
            "invoices_count" => 1,
            "amount_cents" => 3000.0
          }), hash_including({
            "month" => Time.current.beginning_of_month - 2.months,
            "currency" => "EUR",
            "billing_entity_id" => billing_entity2.id,
            "invoices_count" => 1,
            "amount_cents" => 4000.0
          })])
        end
      end

      context "when a customer has invoices across multiple billing entities in the same month and currency" do
        let(:customer) { create(:customer, organization:) }
        let(:invoices) {
          [
            create(:invoice, organization:, customer:, total_amount_cents: 1000, issuing_date: 1.month.ago, billing_entity: billing_entity1),
            create(:invoice, organization:, customer:, total_amount_cents: 2000, issuing_date: 1.month.ago, billing_entity: billing_entity2)
          ]
        }

        it "emits one row per billing entity for the same (month, currency) bucket" do
          expect(gross_revenues).to match_array([hash_including({
            "month" => Time.current.beginning_of_month - 1.month,
            "currency" => "EUR",
            "billing_entity_id" => billing_entity1.id,
            "invoices_count" => 1,
            "amount_cents" => 1000.0
          }), hash_including({
            "month" => Time.current.beginning_of_month - 1.month,
            "currency" => "EUR",
            "billing_entity_id" => billing_entity2.id,
            "invoices_count" => 1,
            "amount_cents" => 2000.0
          })])
        end
      end
    end

    context "when filtering by billing_entity_id" do
      let(:args) { {billing_entity_id: billing_entity1.id} }

      it "returns all gross revenues for the billing entity" do
        expect(gross_revenues).to match_array([hash_including({
          "month" => Time.current.beginning_of_month - 1.month,
          "currency" => "EUR",
          "billing_entity_id" => billing_entity1.id,
          "invoices_count" => 1,
          "amount_cents" => 1000.0
        }), hash_including({
          "month" => Time.current.beginning_of_month - 2.months,
          "currency" => "EUR",
          "billing_entity_id" => billing_entity1.id,
          "invoices_count" => 1,
          "amount_cents" => 3000.0
        })])
      end

      context "with pay_in_advance fees on other billing entities" do
        let(:customer1) { create(:customer, organization:, billing_entity: billing_entity1) }
        let(:customer2) { create(:customer, organization:, billing_entity: billing_entity2) }
        let(:subscription1) { create(:subscription, customer: customer1) }
        let(:subscription2) { create(:subscription, customer: customer2) }

        before do
          create(:fee, organization:, billing_entity: billing_entity1, subscription: subscription1,
            invoice: nil, pay_in_advance: true, amount_cents: 500, amount_currency: "EUR",
            created_at: 1.month.ago)
          create(:fee, organization:, billing_entity: billing_entity2, subscription: subscription2,
            invoice: nil, pay_in_advance: true, amount_cents: 9999, amount_currency: "EUR",
            created_at: 1.month.ago)
        end

        it "excludes pay_in_advance fees from other billing entities" do
          billing_entity_ids = gross_revenues.map { |r| r["billing_entity_id"] }.uniq
          expect(billing_entity_ids).to eq([billing_entity1.id])
        end
      end
    end
  end
end
