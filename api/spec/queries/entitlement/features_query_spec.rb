# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entitlement::FeaturesQuery do
  let(:organization) { create(:organization) }
  let!(:feature1) { create(:feature, organization:, code: "seats", name: "Number of seats") }
  let!(:feature2) { create(:feature, organization:, code: "storage", name: "Storage") }
  let!(:feature3) { create(:feature, organization:, code: "api_calls", name: "API Calls") }
  let!(:other_organization_feature) { create(:feature, organization: create(:organization), code: "other") }

  describe "#call" do
    subject { described_class.call(organization:, pagination:, search_term:, filters:) }

    let(:pagination) { {page: nil, limit: nil} }
    let(:search_term) { nil }
    let(:filters) { {} }

    it "returns features for the organization" do
      result = subject

      expect(result).to be_success
      expect(result.features).to contain_exactly(feature1, feature2, feature3)
    end

    it "applies pagination" do
      result = described_class.call(
        organization:,
        pagination: {page: 1, limit: 2}
      )

      expect(result).to be_success
      expect(result.features.count).to eq(2)
    end

    it "applies search term to name" do
      result = described_class.call(
        organization:,
        search_term: "seats"
      )

      expect(result).to be_success
      expect(result.features).to include(feature1)
      expect(result.features).not_to include(feature2, feature3)
    end

    it "applies search term to code" do
      result = described_class.call(
        organization:,
        search_term: "storage"
      )

      expect(result).to be_success
      expect(result.features).to include(feature2)
      expect(result.features).not_to include(feature1, feature3)
    end

    it "applies search term with partial matches" do
      result = described_class.call(
        organization:,
        search_term: "api"
      )

      expect(result).to be_success
      expect(result.features).to include(feature3)
      expect(result.features).not_to include(feature1, feature2)
    end

    it "applies consistent ordering" do
      result = subject

      expect(result).to be_success
      expect(result.features.to_a).to eq(result.features.order(created_at: :desc, id: :asc).to_a)
    end

    context "with pagination parameters" do
      let(:pagination) { {page: 1, limit: 1} }

      it "returns paginated results" do
        result = subject

        expect(result).to be_success
        expect(result.features.count).to eq(1)
        expect(result.features.first.code).to eq(feature3.code)
      end

      it "returns different results for different pages" do
        result1 = described_class.call(organization:, pagination: {page: 1, limit: 1})
        result2 = described_class.call(organization:, pagination: {page: 2, limit: 1})

        expect(result1.features).not_to eq(result2.features)
      end
    end

    context "with search term" do
      let(:search_term) { "seats" }

      it "filters results by search term" do
        result = subject

        expect(result).to be_success
        expect(result.features).to contain_exactly(feature1)
      end

      context "when search term is blank" do
        let(:search_term) { "" }

        it "returns all features" do
          result = subject

          expect(result).to be_success
          expect(result.features).to contain_exactly(feature1, feature2, feature3)
        end
      end
    end

    context "with filters" do
      let(:filters) { {organization_id: organization.id} }

      it "applies filters" do
        result = subject

        expect(result).to be_success
        expect(result.features).to include(feature1, feature2, feature3)
        expect(result.features).not_to include(other_organization_feature)
      end
    end

    context "when organization has no features" do
      let(:empty_organization) { create(:organization) }

      it "returns empty result" do
        result = described_class.call(organization: empty_organization)

        expect(result).to be_success
        expect(result.features).to be_empty
      end
    end

    context "with invalid pagination" do
      let(:pagination) { {page: -1, limit: -1} }

      it "still returns a successful result" do
        result = subject

        expect(result).to be_success
        expect(result.features).to be_present
      end
    end
  end
end
