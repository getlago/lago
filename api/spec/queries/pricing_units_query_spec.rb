# frozen_string_literal: true

require "rails_helper"

RSpec.describe PricingUnitsQuery do
  subject(:result) { described_class.call(organization:, search_term:, pagination:) }

  let(:organization) { create(:organization) }
  let(:pagination) { nil }
  let(:search_term) { nil }

  context "when no filters applied" do
    let!(:pricing_units) do
      [
        create(:pricing_unit, name: "Beta", organization:),
        create(:pricing_unit, name: "Alpha", organization:, created_at: 2.days.ago),
        create(:pricing_unit, name: "Alpha", organization:, created_at: 1.day.ago)
      ]
    end

    before { create(:pricing_unit) }

    it "returns all pricing units for the organization ordered by name asc, created_at desc" do
      expect(result).to be_success
      expect(result.pricing_units.pluck(:id)).to eq pricing_units.reverse.map(&:id)
    end
  end

  context "when pagination options provided" do
    let(:pagination) { {page: 2, limit: 1} }

    let!(:pricing_units) do
      [
        create(:pricing_unit, name: "Beta", organization:),
        create(:pricing_unit, name: "Alpha", organization:, created_at: 2.days.ago),
        create(:pricing_unit, name: "Alpha", organization:, created_at: 1.day.ago)
      ]
    end

    it "returns paginated pricing units" do
      expect(result).to be_success
      expect(result.pricing_units).to contain_exactly pricing_units.second
      expect(result.pricing_units.current_page).to eq 2
      expect(result.pricing_units.total_pages).to eq 3
      expect(result.pricing_units.total_count).to eq 3
    end
  end

  context "when search term filter applied" do
    context "with term matching pricing unit by name" do
      let!(:matching_pricing_unit) { create(:pricing_unit, name: "Cloud token", organization:) }
      let(:search_term) { "Cloud" }

      before { create(:pricing_unit, name: "Credits", organization:) }

      it "returns pricing units by partially matching name" do
        expect(result).to be_success
        expect(result.pricing_units.pluck(:id)).to contain_exactly matching_pricing_unit.id
      end
    end

    context "with term matching pricing unit by code" do
      let!(:matching_pricing_unit) { create(:pricing_unit, code: "cloud_token", organization:) }
      let(:search_term) { "cloud" }

      before { create(:pricing_unit, code: "credits", organization:) }

      it "returns pricing units by partially matching code" do
        expect(result).to be_success
        expect(result.pricing_units.pluck(:id)).to contain_exactly matching_pricing_unit.id
      end
    end

    context "with term not matching any pricing unit" do
      let(:search_term) { "NonExistent" }

      before { create(:pricing_unit, organization:) }

      it "returns empty result" do
        expect(result).to be_success
        expect(result.pricing_units).to be_empty
      end
    end
  end

  context "when both search and pagination are applied" do
    let(:pagination) { {page: 2, limit: 1} }
    let(:search_term) { "Token" }

    let!(:matching_pricing_units) do
      [
        create(:pricing_unit, name: "Cloud token", organization:),
        create(:pricing_unit, name: "Compute token", organization:),
        create(:pricing_unit, name: "Token", organization:)
      ]
    end

    before { create(:pricing_unit, organization:) }

    it "returns paginated and filtered pricing units" do
      expect(result).to be_success
      expect(result.pricing_units).to contain_exactly matching_pricing_units.second
      expect(result.pricing_units.current_page).to eq 2
      expect(result.pricing_units.total_pages).to eq 3
      expect(result.pricing_units.total_count).to eq 3
    end
  end
end
