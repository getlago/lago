# frozen_string_literal: true

require "rails_helper"

RSpec.describe "exports_credit_notes view" do # rubocop:disable RSpec/DescribeClass
  let(:credit_note) { create(:credit_note) }

  def row_for(id)
    ActiveRecord::Base.connection.select_one(
      "SELECT * FROM exports_credit_notes WHERE lago_id = #{ActiveRecord::Base.connection.quote(id)}"
    )
  end

  # Parsing the JSON aggregate columns in place keeps the final comparison a
  # single hash covering every column of the view.
  def parsed_row_for(id)
    row = row_for(id)
    %w[items metadata error_details].each do |column|
      row[column] = row[column] && JSON.parse(row[column])
    end
    row
  end

  describe "full row" do
    context "with a fully populated credit note" do
      let(:credit_note) do
        create(
          :credit_note,
          sequential_id: 42,
          description: "a refund",
          total_amount_cents: 1500,
          total_amount_currency: "USD",
          taxes_amount_cents: 200,
          balance_amount_cents: 1300,
          credit_amount_cents: 1000,
          refund_amount_cents: 300,
          coupons_adjustment_amount_cents: 50,
          precise_coupons_adjustment_amount_cents: 0.5,
          taxes_rate: 20.0,
          refunded_at: Time.current,
          credit_status: :available,
          refund_status: :pending,
          reason: :duplicated_charge
        )
      end

      let!(:item) do
        create(:credit_note_item, credit_note:, precise_amount_cents: 100.4, amount_cents: 100, amount_currency: "EUR")
      end
      let!(:error_detail) do
        create(:error_detail, owner: credit_note, organization: credit_note.organization, error_code: "tax_error", details: {"foo" => "bar"})
      end

      let(:expected_row) do
        credit_note.reload
        {
          "organization_id" => credit_note.organization_id,
          "lago_id" => credit_note.id,
          "sequential_id" => 42,
          "number" => credit_note.number,
          "lago_invoice_id" => credit_note.invoice_id,
          "issuing_date" => credit_note.issuing_date,
          "credit_status" => "available",
          "refund_status" => "pending",
          "reason" => "duplicated_charge",
          "description" => "a refund",
          "currency" => "USD",
          "total_amount_cents" => 1500,
          "taxes_amount_cents" => 200,
          # SUM(precise_amount_cents)::bigint casts 100.4 to 100 BEFORE subtracting
          # the coupons adjustment, then ROUND(100 - 0.5) = ROUND(99.5) = 100.
          "sub_total_excluding_taxes_amount_cents" => 100,
          "balance_amount_cents" => 1300,
          "credit_amount_cents" => 1000,
          "refund_amount_cents" => 300,
          "coupons_adjustment_amount_cents" => 50,
          "taxes_rate" => 20.0,
          "created_at" => credit_note.created_at,
          "updated_at" => credit_note.updated_at,
          "refunded_at" => credit_note.refunded_at,
          "items" => [
            {
              "lago_id" => item.id,
              "amount_cents" => 100,
              "amount_currency" => "EUR",
              "lago_fee_id" => item.fee_id
            }
          ],
          "metadata" => [
            {
              "key" => "key",
              "value" => "value"
            }
          ],
          # The view exports the raw integer error_code column, not the enum string.
          "error_details" => [
            {
              "lago_id" => error_detail.id,
              "error_code" => ErrorDetail.error_codes["tax_error"],
              "details" => {"foo" => "bar"}
            }
          ]
        }
      end

      before do
        create(:item_metadata, owner: credit_note, organization: credit_note.organization, value: {"key" => "value"})
      end

      it "exposes every column of the view" do
        expect(parsed_row_for(credit_note.id)).to eq(expected_row)
      end
    end

    context "with a bare credit note" do
      let(:credit_note) do
        create(
          :credit_note,
          sequential_id: 7,
          description: nil,
          total_amount_cents: 800,
          total_amount_currency: "EUR",
          taxes_amount_cents: 0,
          balance_amount_cents: 800,
          credit_amount_cents: 800,
          refund_amount_cents: 0,
          coupons_adjustment_amount_cents: 0,
          precise_coupons_adjustment_amount_cents: 0,
          taxes_rate: 0.0,
          refunded_at: nil,
          credit_status: :available,
          refund_status: :pending,
          reason: :other
        )
      end

      let(:expected_row) do
        credit_note.reload
        {
          "organization_id" => credit_note.organization_id,
          "lago_id" => credit_note.id,
          "sequential_id" => 7,
          "number" => credit_note.number,
          "lago_invoice_id" => credit_note.invoice_id,
          "issuing_date" => credit_note.issuing_date,
          "credit_status" => "available",
          "refund_status" => "pending",
          "reason" => "other",
          "description" => nil,
          "currency" => "EUR",
          "total_amount_cents" => 800,
          "taxes_amount_cents" => 0,
          # SUM over zero items is NULL, and NULL minus the adjustment stays NULL.
          "sub_total_excluding_taxes_amount_cents" => nil,
          "balance_amount_cents" => 800,
          "credit_amount_cents" => 800,
          "refund_amount_cents" => 0,
          "coupons_adjustment_amount_cents" => 0,
          "taxes_rate" => 0.0,
          "created_at" => credit_note.created_at,
          "updated_at" => credit_note.updated_at,
          "refunded_at" => nil,
          "items" => nil,
          "metadata" => nil,
          "error_details" => nil
        }
      end

      it "exposes every column with NULL aggregates" do
        expect(parsed_row_for(credit_note.id)).to eq(expected_row)
      end
    end
  end

  describe "enum CASE mappings" do
    def value_for(id, column)
      row_for(id)[column]
    end

    context "with credit_status" do
      {available: "available", consumed: "consumed", voided: "voided"}.each do |enum_name, expected|
        it "maps #{enum_name} to '#{expected}'" do
          cn = create(:credit_note, credit_status: enum_name)

          expect(value_for(cn.id, "credit_status")).to eq(expected)
        end
      end
    end

    context "with refund_status" do
      {pending: "pending", succeeded: "succeeded", failed: "failed"}.each do |enum_name, expected|
        it "maps #{enum_name} to '#{expected}'" do
          cn = create(:credit_note, refund_status: enum_name)

          expect(value_for(cn.id, "refund_status")).to eq(expected)
        end
      end
    end

    context "with reason" do
      {
        duplicated_charge: "duplicated_charge",
        product_unsatisfactory: "product_unsatisfactory",
        order_change: "order_change",
        order_cancellation: "order_cancellation",
        fraudulent_charge: "fraudulent_charge",
        other: "other"
      }.each do |enum_name, expected|
        it "maps #{enum_name} to '#{expected}'" do
          cn = create(:credit_note, reason: enum_name)

          expect(value_for(cn.id, "reason")).to eq(expected)
        end
      end
    end
  end

  describe "sub_total_excluding_taxes_amount_cents" do
    def sub_total_for(id)
      row_for(id)["sub_total_excluding_taxes_amount_cents"]
    end

    context "when the credit note has items" do
      let(:credit_note) { create(:credit_note, precise_coupons_adjustment_amount_cents: 0.5) }

      before do
        create(:credit_note_item, credit_note:, precise_amount_cents: 100.4)
        create(:credit_note_item, credit_note:, precise_amount_cents: 200.3)
      end

      # SUM(precise_amount_cents)::bigint rounds 300.7 to 301 before subtracting,
      # then ROUND(301 - 0.5) = ROUND(300.5) = 301.
      it "rounds the bigint sum minus the coupons adjustment" do
        expect(sub_total_for(credit_note.id)).to eq(301)
      end
    end
  end

  describe "items aggregation" do
    def items_for(id)
      raw = row_for(id)["items"]
      raw && JSON.parse(raw)
    end

    context "when the credit note has multiple items" do
      let!(:item_one) { create(:credit_note_item, credit_note:, amount_cents: 100, amount_currency: "EUR") }
      let!(:item_two) { create(:credit_note_item, credit_note:, amount_cents: 250, amount_currency: "USD") }

      it "aggregates each item as a JSON object regardless of order" do
        items = items_for(credit_note.id)

        tuples = items.map { |i| [i["lago_id"], i["amount_cents"], i["amount_currency"], i["lago_fee_id"]] }
        expect(tuples).to match_array(
          [
            [item_one.id, 100, "EUR", item_one.fee_id],
            [item_two.id, 250, "USD", item_two.fee_id]
          ]
        )
      end
    end
  end

  describe "row presence" do
    let!(:available_note) { create(:credit_note, credit_status: :available) }
    let!(:voided_note) { create(:credit_note, credit_status: :voided) }
    let!(:draft_note) { create(:credit_note, :draft) }

    # The view has no WHERE clause, so draft and voided notes still appear.
    it "exposes every credit note regardless of status" do
      ids = [available_note.id, voided_note.id, draft_note.id]
      quoted_ids = ids.map { |id| ActiveRecord::Base.connection.quote(id) }.join(",")
      count = ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM exports_credit_notes WHERE lago_id IN (#{quoted_ids})"
      )

      expect(count).to eq(3)
    end
  end

  describe "metadata aggregation" do
    def metadata_for(id)
      row_for(id)["metadata"]
    end

    context "when the credit note has multiple metadata keys" do
      let(:value) { {"key" => "value", "another" => "thing"} }

      before { create(:item_metadata, owner: credit_note, organization: credit_note.organization, value:) }

      it "returns one row per metadata key as a JSON array" do
        parsed = JSON.parse(metadata_for(credit_note.id))

        expect(parsed.map { |m| [m["key"], m["value"]] }).to match_array([["key", "value"], ["another", "thing"]])
      end
    end

    context "when metadata with the same owner_id belongs to a different owner_type" do
      let(:wallet) { create(:wallet, id: credit_note.id) }

      before { create(:item_metadata, owner: wallet, organization: credit_note.organization, value: {"leak" => "no"}) }

      it "does not leak the other owner's metadata into the credit note row" do
        expect(metadata_for(credit_note.id)).to be_nil
      end
    end
  end

  describe "error_details aggregation" do
    def error_details_for(id)
      row_for(id)["error_details"]
    end

    context "when an error detail with the same owner_id belongs to a different owner_type" do
      let(:wallet) { create(:wallet, id: credit_note.id) }

      before { create(:error_detail, owner: wallet, organization: credit_note.organization, error_code: "tax_error") }

      it "does not leak the other owner's error detail into the credit note row" do
        expect(error_details_for(credit_note.id)).to be_nil
      end
    end
  end
end
