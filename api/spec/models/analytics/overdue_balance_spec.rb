# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::OverdueBalance do
  describe ".cache_key" do
    subject(:overdue_balance_cache_key) { described_class.cache_key(organization_id, **args) }

    let(:organization_id) { SecureRandom.uuid }
    let(:billing_entity_id) { SecureRandom.uuid }
    let(:external_customer_id) { "customer_01" }
    let(:currency) { "EUR" }
    let(:months) { 12 }
    let(:date) { Date.current.strftime("%Y-%m-%d") }

    context "with no arguments" do
      let(:args) { {} }
      let(:cache_key) { "overdue-balance/#{date}/#{organization_id}////" }

      it "returns the cache key" do
        expect(overdue_balance_cache_key).to eq(cache_key)
      end
    end

    context "with customer external id, currency and months" do
      let(:args) { {external_customer_id:, currency:, months:} }

      let(:cache_key) do
        "overdue-balance/#{date}/#{organization_id}//#{external_customer_id}/#{currency}/#{months}"
      end

      it "returns the cache key" do
        expect(overdue_balance_cache_key).to eq(cache_key)
      end

      context "with billing_entity_id" do
        let(:args) { {billing_entity_id:, external_customer_id:, currency:, months:} }
        let(:cache_key) do
          "overdue-balance/#{date}/#{organization_id}/#{billing_entity_id}/#{external_customer_id}/#{currency}/#{months}"
        end

        it "returns the cache key" do
          expect(overdue_balance_cache_key).to eq(cache_key)
        end
      end
    end

    context "with customer external id" do
      let(:args) { {external_customer_id:} }

      let(:cache_key) do
        "overdue-balance/#{date}/#{organization_id}//#{external_customer_id}//"
      end

      it "returns the cache key" do
        expect(overdue_balance_cache_key).to eq(cache_key)
      end
    end

    context "with currency" do
      let(:args) { {currency:} }
      let(:cache_key) { "overdue-balance/#{date}/#{organization_id}///#{currency}/" }

      it "returns the cache key" do
        expect(overdue_balance_cache_key).to eq(cache_key)
      end
    end

    context "with billing_entity_id" do
      let(:args) { {billing_entity_id:} }
      let(:cache_key) { "overdue-balance/#{date}/#{organization_id}/#{billing_entity_id}///" }

      it "returns the cache key" do
        expect(overdue_balance_cache_key).to eq(cache_key)
      end
    end
  end

  describe ".find_all_by" do
    subject(:overdue_balances) { described_class.find_all_by(organization.id, **args) }

    let(:organization) { create(:organization, created_at: 3.months.ago) }
    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:) }
    let(:billing_entity1) { organization.default_billing_entity }
    let(:billing_entity2) { create(:billing_entity, organization: organization) }
    let(:invoice1) do
      create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 1.month.ago,
        total_amount_cents: 100, billing_entity: billing_entity1, issuing_date: 1.month.ago)
    end
    let(:invoice2) do
      create(:invoice, customer:, organization:, payment_overdue: false, payment_due_date: 1.month.ago,
        total_amount_cents: 200, billing_entity: billing_entity2, issuing_date: 1.month.ago)
    end
    let(:invoice3) do
      create(:invoice, customer:, organization:, payment_overdue: false, payment_due_date: 2.months.ago,
        total_amount_cents: 300, billing_entity: billing_entity1, issuing_date: 2.months.ago)
    end
    let(:invoice4) do
      create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 2.months.ago,
        total_amount_cents: 400, billing_entity: billing_entity2, issuing_date: 2.months.ago)
    end

    before do
      invoice1
      invoice2
      invoice3
      invoice4
    end

    context "with no arguments" do
      let(:args) { {} }

      it "returns the overdue balances with billing_entity_id" do
        expect(overdue_balances).to match_array([
          hash_including({
            "month" => Time.current.beginning_of_month - 2.months,
            "currency" => "EUR",
            "billing_entity_id" => billing_entity2.id,
            "amount_cents" => 400,
            "lago_invoice_ids" => "[[\"#{invoice4.id}\"]]"
          }), hash_including({
            "month" => Time.current.beginning_of_month - 1.month,
            "currency" => "EUR",
            "billing_entity_id" => billing_entity1.id,
            "amount_cents" => 100,
            "lago_invoice_ids" => "[[\"#{invoice1.id}\"]]"
          })
        ])
      end

      context "when overdue invoices share the same (month, currency) across billing entities" do
        let(:cross_entity_invoice) do
          create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 1.month.ago,
            total_amount_cents: 500, billing_entity: billing_entity2, issuing_date: 1.month.ago)
        end

        before { cross_entity_invoice }

        it "emits one row per billing entity for the same (month, currency) bucket" do
          one_month_ago_rows = overdue_balances.select do |row|
            row["month"] == Time.current.beginning_of_month - 1.month && row["currency"] == "EUR"
          end

          expect(one_month_ago_rows).to match_array([
            hash_including({
              "billing_entity_id" => billing_entity1.id,
              "amount_cents" => 100,
              "lago_invoice_ids" => "[[\"#{invoice1.id}\"]]"
            }),
            hash_including({
              "billing_entity_id" => billing_entity2.id,
              "amount_cents" => 500,
              "lago_invoice_ids" => "[[\"#{cross_entity_invoice.id}\"]]"
            })
          ])
        end
      end
    end

    context "with billing entity id" do
      let(:args) { {billing_entity_id: billing_entity1.id} }

      it "returns the overdue balances for provided billing_entity only" do
        expect(overdue_balances).to match_array([
          hash_including({
            "month" => Time.current.beginning_of_month - 1.month,
            "currency" => "EUR",
            "billing_entity_id" => billing_entity1.id,
            "amount_cents" => 100,
            "lago_invoice_ids" => "[[\"#{invoice1.id}\"]]"
          })
        ])
      end
    end

    context "with billing entity code" do
      let(:args) { {billing_entity_code: billing_entity2.code} }

      it "returns the overdue balances for provided billing_entity only" do
        expect(overdue_balances).to match_array([
          hash_including({
            "month" => Time.current.beginning_of_month - 2.months,
            "currency" => "EUR",
            "billing_entity_id" => billing_entity2.id,
            "amount_cents" => 400,
            "lago_invoice_ids" => "[[\"#{invoice4.id}\"]]"
          })
        ])
      end
    end

    context "with special invoice scenarios" do
      let(:args) { {} }

      context "with credit notes offsetting invoice amounts" do
        let(:invoice_with_credit) do
          create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 1.month.ago,
            total_amount_cents: 1000, billing_entity: billing_entity1, issuing_date: 1.month.ago)
        end

        before do
          invoice_with_credit
          create(:credit_note, invoice: invoice_with_credit, customer:, status: :finalized,
            total_amount_cents: 300, credit_amount_cents: 300, balance_amount_cents: 300,
            refund_amount_cents: 0, coupons_adjustment_amount_cents: 0, offset_amount_cents: 300)
        end

        it "deducts credit note offset from the overdue amount" do
          result = overdue_balances.find { |r| r["lago_invoice_ids"].include?(invoice_with_credit.id) }
          expect(result["amount_cents"]).to eq(800) # invoice1 (100) + invoice_with_credit (1000 - 300)
        end
      end

      context "with self-billed invoices" do
        let(:self_billed_invoice) do
          create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 1.month.ago,
            total_amount_cents: 5000, billing_entity: billing_entity1, issuing_date: 1.month.ago, self_billed: true)
        end

        before { self_billed_invoice }

        it "excludes self-billed invoices from overdue balances" do
          invoice_ids = overdue_balances.flat_map { |r| JSON.parse(r["lago_invoice_ids"]).flatten }
          expect(invoice_ids).not_to include(self_billed_invoice.id)
        end
      end

      context "with partially paid invoices" do
        let(:partially_paid_invoice) do
          create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 1.month.ago,
            total_amount_cents: 1000, total_paid_amount_cents: 400, billing_entity: billing_entity1, issuing_date: 1.month.ago)
        end

        before { partially_paid_invoice }

        it "calculates overdue amount as total minus paid amount" do
          result = overdue_balances.find { |r| r["lago_invoice_ids"].include?(partially_paid_invoice.id) }
          expect(result["amount_cents"]).to eq(700) # invoice1 (100) + partially_paid_invoice (1000 - 400)
        end
      end

      context "with only finalized credit notes" do
        let(:invoice_with_draft_credit) do
          create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 1.month.ago,
            total_amount_cents: 1000, billing_entity: billing_entity1, issuing_date: 1.month.ago)
        end

        before do
          invoice_with_draft_credit
          create(:credit_note, invoice: invoice_with_draft_credit, customer:, status: :draft,
            total_amount_cents: 200, credit_amount_cents: 200, balance_amount_cents: 200,
            refund_amount_cents: 0, coupons_adjustment_amount_cents: 0, offset_amount_cents: 200)
        end

        it "only includes finalized credit notes in offset calculation" do
          result = overdue_balances.find { |r| r["lago_invoice_ids"].include?(invoice_with_draft_credit.id) }
          expect(result["amount_cents"]).to eq(1100) # invoice1 (100) + invoice_with_draft_credit (1000, draft credit note not applied)
        end
      end
    end

    context "with filters" do
      context "with currency filter" do
        let(:args) { {currency: "USD"} }
        let(:usd_invoice) do
          create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 1.month.ago,
            total_amount_cents: 500, currency: "USD", billing_entity: billing_entity1, issuing_date: 1.month.ago)
        end

        before { usd_invoice }

        it "returns only invoices with the specified currency" do
          expect(overdue_balances.map { |r| r["currency"] }.uniq).to eq(["USD"])
          result = overdue_balances.find { |r| r["lago_invoice_ids"].include?(usd_invoice.id) }
          expect(result).to be_present
        end

        it "excludes invoices with different currencies" do
          invoice_ids = overdue_balances.flat_map { |r| JSON.parse(r["lago_invoice_ids"]).flatten }
          expect(invoice_ids).not_to include(invoice1.id, invoice4.id) # EUR invoices
        end
      end

      context "with external_customer_id filter" do
        let(:args) { {external_customer_id: customer.external_id} }
        let(:other_customer) { create(:customer, organization:, external_id: "other_customer") }
        let(:other_invoice) do
          create(:invoice, customer: other_customer, organization:, payment_overdue: true,
            payment_due_date: 1.month.ago, total_amount_cents: 999, billing_entity: billing_entity1, issuing_date: 1.month.ago)
        end

        before { other_invoice }

        it "returns only overdue balances for the specified customer" do
          invoice_ids = overdue_balances.flat_map { |r| JSON.parse(r["lago_invoice_ids"]).flatten }
          expect(invoice_ids).to include(invoice1.id)
          expect(invoice_ids).not_to include(other_invoice.id)
        end
      end

      context "with deleted customer" do
        let(:deleted_customer) { create(:customer, organization:, deleted_at: 1.day.ago) }
        let(:args) { {external_customer_id: deleted_customer.external_id} }

        before do
          create(:invoice, customer: deleted_customer, organization:, payment_overdue: true,
            payment_due_date: 1.month.ago, total_amount_cents: 888, billing_entity: billing_entity1, issuing_date: 1.month.ago)
        end

        it "excludes invoices from deleted customers" do
          expect(overdue_balances).to be_empty
        end
      end
    end
  end
end
