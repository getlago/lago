# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
require "rails_helper"

RSpec.describe Pagination do
  subject(:result) { instance.pagination_metadata(records) }

  let(:instance) { dummy_class.new }
  let(:dummy_class) do
    Class.new do
      include Pagination

      public :_count_total, :pagination_metadata
    end
  end
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:records) { double("records", total_count: 25, current_page: 2, limit_value: 10) }
  let(:key) { "invoices" }
  let(:organization_id) { SecureRandom.uuid }

  before { allow(Rails).to receive(:cache).and_return(cache) }

  context "when records are present" do
    it "returns correct metadata" do
      expect(result).to eq(
        "current_page" => 2,
        "next_page" => 3,
        "prev_page" => 1,
        "total_pages" => 3,
        "total_count" => 25
      )
    end
  end

  context "when on the first page" do
    let(:records) { double("records", total_count: 25, current_page: 1, limit_value: 10) }

    it "returns nil for prev_page" do
      expect(result["prev_page"]).to be_nil
    end
  end

  context "when on the last page" do
    let(:records) { double("records", total_count: 25, current_page: 3, limit_value: 10) }

    it "returns nil for next_page" do
      expect(result["next_page"]).to be_nil
    end
  end

  context "when total_count is zero" do
    let(:records) { double("records", total_count: 0) }

    it "returns zeroed metadata" do
      expect(result).to eq(
        "current_page" => 0,
        "next_page" => nil,
        "prev_page" => nil,
        "total_pages" => 0,
        "total_count" => 0
      )
    end
  end

  context "when count is cached" do
    subject(:result) { instance.pagination_metadata(records, key:, organization_id:, params:) }

    let(:params) { {"per_page" => "10", "page" => "1", "status" => "active"}.with_indifferent_access }
    let(:records) { double("records", current_page: 1, limit_value: 10) }

    before { instance._count_total(key:, organization_id:, params:) { 99 } }

    it "uses cached count instead of records.total_count" do
      expect(result["total_count"]).to eq(99)
      expect(result["total_pages"]).to eq(10)
    end
  end

  context "when cache is stale on the last page" do
    subject(:result) { instance.pagination_metadata(records, key:, organization_id:, params: query_params) }

    let(:query_params) { {"per_page" => "10", "page" => "10", "status" => "active"}.with_indifferent_access }
    let(:records) { double("records", total_count: 105, current_page: 10, limit_value: 10) }

    before do
      instance._count_total(key: "invoices", organization_id:, params: query_params.merge("page" => "1")) { 99 }
    end

    it "re-calculates from records" do
      expect(result["total_count"]).to eq(105)
      expect(result["total_pages"]).to eq(11)
    end
  end

  context "when records do not respond to limit_value" do
    let(:records) { double("records", total_count: 25, current_page: 2, total_pages: 3, next_page: 3, prev_page: 1) }

    it "uses precomputed pagination attributes" do
      expect(result).to eq(
        "current_page" => 2,
        "next_page" => 3,
        "prev_page" => 1,
        "total_pages" => 3,
        "total_count" => 25
      )
    end
  end

  context "when nested params are in different order" do
    let(:organization_id) { SecureRandom.uuid }

    it "hits the same cache entry" do
      params_asc = {"per_page" => "10", "page" => "1", "metadata" => {"a" => "1", "b" => "2"}}.with_indifferent_access
      instance._count_total(key: "invoices", organization_id:, params: params_asc) { 77 }

      params_desc = {"metadata" => {"b" => "2", "a" => "1"}, "page" => "1", "per_page" => "10"}.with_indifferent_access
      records = double("records", current_page: 1, limit_value: 10)
      result = instance.pagination_metadata(records, key:, organization_id:, params: params_desc)
      expect(result["total_count"]).to eq(77)
    end
  end

  context "with different filter params" do
    let(:organization_id) { SecureRandom.uuid }

    it "does not share cache across different queries" do
      params = {"per_page" => "10", "page" => "1", "status" => "active"}.with_indifferent_access
      instance._count_total(key: "invoices", organization_id:, params:) { 99 }
      records = double("records", current_page: 1, limit_value: 10)
      result = instance.pagination_metadata(records, key:, organization_id:, params:)
      expect(result["total_count"]).to eq(99)

      params = {"per_page" => "10", "page" => "1", "status" => "draft"}.with_indifferent_access
      records = double("records", total_count: 5, current_page: 1, limit_value: 10)
      result = instance.pagination_metadata(records, key:, organization_id:, params:)
      expect(result["total_count"]).to eq(5)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
