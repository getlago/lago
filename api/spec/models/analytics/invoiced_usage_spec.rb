# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::InvoicedUsage do
  describe ".cache_key" do
    subject(:invoiced_usage_cache_key) { described_class.cache_key(organization_id, **args) }

    let(:organization_id) { SecureRandom.uuid }
    let(:billing_entity_id) { SecureRandom.uuid }
    let(:currency) { "EUR" }
    let(:months) { 12 }
    let(:date) { Date.current.strftime("%Y-%m-%d") }

    context "with no arguments" do
      let(:args) { {} }
      let(:cache_key) { "invoiced-usage/#{date}/#{organization_id}///" }

      it "returns the cache key" do
        expect(invoiced_usage_cache_key).to eq(cache_key)
      end
    end

    context "with currency and months" do
      let(:args) { {currency:, months:} }

      let(:cache_key) do
        "invoiced-usage/#{date}/#{organization_id}//#{currency}/#{months}"
      end

      it "returns the cache key" do
        expect(invoiced_usage_cache_key).to eq(cache_key)
      end

      context "with billing entity id" do
        let(:args) { {currency:, months:, billing_entity_id:} }
        let(:cache_key) do
          "invoiced-usage/#{date}/#{organization_id}/#{billing_entity_id}/#{currency}/#{months}"
        end

        it "returns the cache key" do
          expect(invoiced_usage_cache_key).to eq(cache_key)
        end
      end
    end

    context "with months" do
      let(:args) { {months:} }

      let(:cache_key) do
        "invoiced-usage/#{date}/#{organization_id}///#{months}"
      end

      it "returns the cache key" do
        expect(invoiced_usage_cache_key).to eq(cache_key)
      end
    end

    context "with currency" do
      let(:args) { {currency:} }
      let(:cache_key) { "invoiced-usage/#{date}/#{organization_id}//#{currency}/" }

      it "returns the cache key" do
        expect(invoiced_usage_cache_key).to eq(cache_key)
      end
    end

    context "with billing_entity_id" do
      let(:args) { {billing_entity_id:} }
      let(:cache_key) { "invoiced-usage/#{date}/#{organization_id}/#{billing_entity_id}//" }

      it "returns the cache key" do
        expect(invoiced_usage_cache_key).to eq(cache_key)
      end
    end
  end

  describe ".find_all_by" do
    subject(:invoiced_usages) { described_class.find_all_by(organization.id, **args) }

    let(:organization) { create(:organization, created_at: 3.months.ago) }
    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:) }
    let(:billing_entity1) { organization.default_billing_entity }
    let(:billing_entity2) { create(:billing_entity, organization: organization) }

    let(:billable_metric) { create(:billable_metric, organization:, code: "api_calls") }
    let(:charge) { create(:standard_charge, billable_metric:) }

    let(:fee1) do
      create(:charge_fee, charge:, subscription:, amount_cents: 100, amount_currency: "EUR", created_at: 2.months.ago)
    end

    let(:fee2) do
      create(:charge_fee, charge:, subscription:, amount_cents: 200, amount_currency: "EUR", created_at: 2.months.ago)
    end

    let(:fee3) do
      create(:charge_fee, charge:, subscription:, amount_cents: 300, amount_currency: "EUR", created_at: 1.month.ago)
    end

    let(:fee4) do
      create(:charge_fee, charge:, subscription:, amount_cents: 400, amount_currency: "EUR", created_at: 1.month.ago)
    end

    let(:invoice1) do
      create(:invoice, organization:, billing_entity: billing_entity1, issuing_date: 2.months.ago, status: :finalized, fees: [fee1, fee2])
    end

    let(:invoice2) do
      create(:invoice, organization:, billing_entity: billing_entity2, issuing_date: 1.month.ago, status: :finalized, fees: [fee3, fee4])
    end

    before do
      invoice1
      invoice2
    end

    context "with no arguments" do
      let(:args) { {} }

      it "returns all invoiced usages" do
        expect(invoiced_usages).to match_array([hash_including({
          "amount_cents" => 700.0,
          "code" => "api_calls",
          "currency" => "EUR",
          "month" => Time.current.beginning_of_month - 1.month
        }), hash_including({
          "amount_cents" => 300.0,
          "code" => "api_calls",
          "currency" => "EUR",
          "month" => Time.current.beginning_of_month - 2.months
        })])
      end
    end

    context "with billing_entity_id" do
      let(:args) { {billing_entity_id: billing_entity1.id} }

      it "returns all invoiced usages for the specified billing entity" do
        expect(invoiced_usages).to match_array([hash_including({
          "amount_cents" => 300.0,
          "code" => "api_calls",
          "currency" => "EUR",
          "month" => Time.current.beginning_of_month - 2.months
        })])
      end
    end
  end
end
