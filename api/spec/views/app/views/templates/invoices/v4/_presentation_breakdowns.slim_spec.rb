# frozen_string_literal: true

require "rails_helper"

# The expectations in this spec follow `presentation_breakdowns.md`
# (Examples section, Scenarios 1-3). The spec is the source of truth:
#   - per-charge header renders `fees.first.invoice_name`
#   - fee title row when `fee.grouped_by` is blank reuses the charge
#     `invoice_name` (same value as the per-charge header)
#   - breakdown labels join non-nil values with ", " (nil values are omitted)
#   - rows with nil values are pushed to the end of the list
RSpec.describe "templates/invoices/v4/_presentation_breakdowns.slim" do # rubocop:disable RSpec/DescribeClass
  subject(:rendered_template) do
    Slim::Template.new(template.to_s, pretty: true).render(Object.new, fees: fees)
  end

  let(:template) { Rails.root.join("app/views/templates/invoices/v4/_presentation_breakdowns.slim") }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:properties) {
    {
      "amount" => "100",
      "presentation_group_keys" => [
        {"value" => "region", "options" => {"display_in_invoice" => true}},
        {"value" => "department", "options" => {"display_in_invoice" => true}}
      ]
    }
  }

  let(:charge) do
    create(
      :standard_charge,
      plan:,
      billable_metric:,
      invoice_display_name: "compute",
      properties:
    )
  end

  before { I18n.locale = :en }

  # Scenario 1 — `fee.grouped_by` is empty (no charge filter).
  # Expected rendered table:
  #   | compute         | 110 |
  #   | eu, engineering | 40  |
  #   | us, engineering | 35  |
  #   | us, sales       | 25  |
  #   | us              | 10  |
  context "when fee.grouped_by is empty and there is no charge filter (Scenario 1)" do
    let(:fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        subscription:,
        invoice_display_name: "compute",
        units: 110,
        grouped_by: {}
      )
    end

    let(:fees) { [fee] }

    before do
      create(:presentation_breakdown, fee:, units: 40, presentation_by: {"region" => "eu", "department" => "engineering"})
      create(:presentation_breakdown, fee:, units: 35, presentation_by: {"region" => "us", "department" => "engineering"})
      create(:presentation_breakdown, fee:, units: 25, presentation_by: {"region" => "us", "department" => "sales"})
      create(:presentation_breakdown, fee:, units: 10, presentation_by: {"region" => "us", "department" => nil})
    end

    it "renders the charge invoice_name as the title row when grouped_by is blank" do
      expect(rendered_template.scan(%r{<td[^>]*>\s*compute\s*</td>}).size).to eq(1)
    end

    it "renders the fee's total units in the title row" do
      expect(rendered_template).to include("110")
    end

    it "renders breakdown labels joined by ', ' in lexicographic order with nil-value rows last" do
      label_order = rendered_template.scan(%r{<td[^>]*>\s*(eu, engineering|us, engineering|us, sales|us)\s*</td>}).flatten
      expect(label_order).to eq(["eu, engineering", "us, engineering", "us, sales", "us"])
    end

    it "renders each breakdown row's units" do
      expect(rendered_template).to include("40").and include("35").and include("25").and include("10")
    end

    context "when a presentation key is not displayed in the invoice" do
      let(:properties) do
        {
          "amount" => "100",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => false}},
            {"value" => "department", "options" => {"display_in_invoice" => true}}
          ]
        }
      end

      it "renders breakdown labels joined by ', ' in lexicographic order with nil-value rows last" do
        label_order = rendered_template.scan(%r{<td[^>]*>\s*(engineering|sales)?\s*</td>\s*<td[^>]*>\s*(?:75|25|10)\s*</td>}).map(&:first)
        expect(label_order).to eq(["engineering", "sales", nil])
      end

      it "renders each breakdown row's units" do
        expect(rendered_template).to include("75").and include("25").and include("10")
      end
    end
  end

  # Scenario 2 — `fee.grouped_by` is present.
  # Expected rendered table:
  #   | compute • eu    | 65 |
  #   | eu, engineering | 40 |
  #   | eu, sales       | 20 |
  #   | eu              | 5  |
  context "when fee.grouped_by is present (Scenario 2)" do
    let(:fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        subscription:,
        invoice_display_name: "compute",
        units: 65,
        grouped_by: {"region" => "eu"}
      )
    end

    let(:fees) { [fee] }

    before do
      create(:presentation_breakdown, fee:, units: 40, presentation_by: {"region" => "eu", "department" => "engineering"})
      create(:presentation_breakdown, fee:, units: 20, presentation_by: {"region" => "eu", "department" => "sales"})
      create(:presentation_breakdown, fee:, units: 5, presentation_by: {"region" => "eu", "department" => nil})
    end

    it "renders the grouped_by values as the title row" do
      expect(rendered_template).to match(/>\s*compute • eu\s*</)
    end

    it "renders the fee's total units in the title row" do
      expect(rendered_template).to include("65")
    end

    it "renders breakdown labels using the full displayable_keys (region kept even though fee is grouped by it)" do
      label_order = rendered_template.scan(%r{<td[^>]*>\s*(eu, engineering|eu, sales|eu)\s*</td>}).flatten
      expect(label_order).to eq(["eu, engineering", "eu, sales", "eu"])
    end

    it "renders each breakdown row's units" do
      expect(rendered_template).to include("40").and include("20").and include("5")
    end

    it "pushes the nil-value row to the end" do
      eu_engineering_idx = rendered_template.index("eu, engineering")
      eu_bare_idx = rendered_template =~ %r{<td[^>]*>\s*eu\s*</td>}
      expect(eu_engineering_idx).to be < eu_bare_idx
    end

    context "when a presentation key is not displayed in the invoice" do
      let(:properties) do
        {
          "amount" => "100",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => false}},
            {"value" => "department", "options" => {"display_in_invoice" => true}}
          ]
        }
      end

      it "renders breakdown labels joined by ', ' in lexicographic order with nil-value rows last" do
        label_order = rendered_template.scan(%r{<td[^>]*>\s*(engineering|sales)?\s*</td>\s*<td[^>]*>\s*(?:40|20|5)\s*</td>}).map(&:first)
        expect(label_order).to eq(["engineering", "sales", nil])
      end

      it "renders each breakdown row's units" do
        expect(rendered_template).to include("40").and include("20").and include("5")
      end
    end
  end

  # Scenario 3 — `fee.charge_filter_id` is present (with `fee.grouped_by` empty).
  # The title row is invoice_name followed by " • " and the filter display name.
  # Expected rendered table:
  #   | compute • eu    | 50 |
  #   | eu, engineering | 30 |
  #   | eu, sales       | 15 |
  #   | eu              | 5  |
  context "when fee.charge_filter_id is present and grouped_by is empty (Scenario 3)" do
    let(:charge_filter) do
      create(:charge_filter, charge:, invoice_display_name: "eu")
    end

    let(:fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        charge_filter:,
        subscription:,
        invoice_display_name: "compute",
        units: 50,
        grouped_by: {}
      )
    end

    let(:fees) { [fee] }

    before do
      create(:presentation_breakdown, fee:, units: 30, presentation_by: {"region" => "eu", "department" => "engineering"})
      create(:presentation_breakdown, fee:, units: 15, presentation_by: {"region" => "eu", "department" => "sales"})
      create(:presentation_breakdown, fee:, units: 5, presentation_by: {"region" => "eu", "department" => nil})
    end

    it "renders invoice_name and filter display name joined in the title row" do
      expect(rendered_template).to match(%r{<td[^>]*>\s*compute • eu\s*</td>})
    end

    it "renders the fee's total units in the title row" do
      expect(rendered_template).to include("50")
    end

    it "renders breakdown labels joined by ', ' in lex order with nil-value rows last" do
      label_order = rendered_template.scan(%r{<td[^>]*>\s*(eu, engineering|eu, sales|eu)\s*</td>}).flatten
      expect(label_order).to eq(["eu, engineering", "eu, sales", "eu"])
    end

    it "renders each breakdown row's units" do
      expect(rendered_template).to include("30").and include("15").and include("5")
    end

    context "when a presentation key is not displayed in the invoice" do
      let(:properties) do
        {
          "amount" => "100",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => false}},
            {"value" => "department", "options" => {"display_in_invoice" => true}}
          ]
        }
      end

      it "renders breakdown labels joined by ', ' in lexicographic order with nil-value rows last" do
        label_order = rendered_template.scan(%r{<td[^>]*>\s*(engineering|sales)?\s*</td>\s*<td[^>]*>\s*(?:30|15|5)\s*</td>}).map(&:first)
        expect(label_order).to eq(["engineering", "sales", nil])
      end

      it "renders each breakdown row's units" do
        expect(rendered_template).to include("30").and include("15").and include("5")
      end
    end
  end

  # Scenario 5 — breakdowns only contain keys not in displayable_keys.
  # The fee and its breakdown rows must be omitted entirely.
  context "when presentation breakdowns have no keys matching displayable_keys (Scenario 5)" do
    let(:fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        subscription:,
        invoice_display_name: "compute",
        units: 100,
        grouped_by: {}
      )
    end

    let(:fees) { [fee] }

    before do
      create(:presentation_breakdown, fee:, units: 60, presentation_by: {"country" => "us"})
      create(:presentation_breakdown, fee:, units: 40, presentation_by: {"country" => "eu"})
    end

    it "does not render the fee title row" do
      expect(rendered_template).not_to match(%r{<td[^>]*>\s*compute\s*</td>})
    end

    it "does not render any breakdown values" do
      expect(rendered_template).not_to include("country")
    end

    context "when a presentation key is not displayed in the invoice" do
      let(:properties) do
        {
          "amount" => "100",
          "presentation_group_keys" => [
            {"value" => "country", "options" => {"display_in_invoice" => false}}
          ]
        }
      end

      it "does not render anything" do
        expect(rendered_template).to be_blank
      end

      it "does not render the fee title row" do
        expect(rendered_template).not_to match(%r{<td[^>]*>\s*compute\s*</td>})
      end

      it "does not render any breakdown values" do
        expect(rendered_template).not_to include("us")
        expect(rendered_template).not_to include("eu")
      end
    end
  end

  # Scenario 4 — `fee.charge_filter_id` is present together with a non-empty
  # `fee.grouped_by`. The title row is invoice_name + grouped_by values + filter display name.
  # Expected rendered table:
  #   | compute • eu • eu | 50 |
  #   | eu, engineering   | 30 |
  #   | eu, sales         | 15 |
  #   | eu                | 5  |
  context "when fee.charge_filter_id is present and fee.grouped_by is present (Scenario 4)" do
    let(:charge_filter) do
      create(:charge_filter, charge:, invoice_display_name: "eu")
    end

    let(:fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        charge_filter:,
        subscription:,
        invoice_display_name: "compute",
        units: 50,
        grouped_by: {"region" => "eu"}
      )
    end

    let(:fees) { [fee] }

    before do
      create(:presentation_breakdown, fee:, units: 30, presentation_by: {"region" => "eu", "department" => "engineering"})
      create(:presentation_breakdown, fee:, units: 15, presentation_by: {"region" => "eu", "department" => "sales"})
      create(:presentation_breakdown, fee:, units: 5, presentation_by: {"region" => "eu", "department" => nil})
    end

    it "renders invoice_name, grouped_by and filter display name joined in the title row" do
      expect(rendered_template).to match(%r{<td[^>]*>\s*compute • eu • eu\s*</td>})
    end

    it "renders the fee's total units in the title row" do
      expect(rendered_template).to include("50")
    end

    it "renders breakdown labels joined by ', ' in lex order with nil-value rows last" do
      label_order = rendered_template.scan(%r{<td[^>]*>\s*(eu, engineering|eu, sales|eu)\s*</td>}).flatten
      expect(label_order).to eq(["eu, engineering", "eu, sales", "eu"])
    end

    it "renders each breakdown row's units" do
      expect(rendered_template).to include("30").and include("15").and include("5")
    end

    context "when a presentation key is not displayed in the invoice" do
      let(:properties) do
        {
          "amount" => "100",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => false}},
            {"value" => "department", "options" => {"display_in_invoice" => true}}
          ]
        }
      end

      it "renders breakdown labels joined by ', ' in lexicographic order with nil-value rows last" do
        label_order = rendered_template.scan(%r{<td[^>]*>\s*(engineering|sales)?\s*</td>\s*<td[^>]*>\s*(?:30|15|5)\s*</td>}).map(&:first)
        expect(label_order).to eq(["engineering", "sales", nil])
      end

      it "renders each breakdown row's units" do
        expect(rendered_template).to include("30").and include("15").and include("5")
      end
    end
  end
end
