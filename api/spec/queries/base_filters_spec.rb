# frozen_string_literal: true

require "rails_helper"

RSpec.describe BaseFilters do
  dummy_filters = described_class[:value, :name]

  subject(:filters) { dummy_filters.new(**attributes) }

  let(:attributes) { {value: "test", name: "test"} }

  describe "filters" do
    it "returns the list of filters" do
      expect(filters.filters).to eq({"value" => "test", "name" => "test"})

      expect(filters.value).to eql("test")
      expect(filters.name).to eql("test")
    end

    context "with unexpected attributes" do
      let(:attributes) { {value: "test", name: "test", unexpected: "unexpected"} }

      it "ignores unexpected attributes" do
        expect(filters.filters).to eq({"value" => "test", "name" => "test"})
      end
    end
  end

  describe "key?" do
    it "returns whether the filter exists" do
      expect(filters.key?(:value)).to be(true)
      expect(filters.key?(:name)).to be(true)
      expect(filters.key?(:unexpected)).to be(false)
      expect(filters.key?(:not_defined)).to be(false)
    end
  end

  describe "[]" do
    it "returns the value of the filter" do
      expect(filters[:value]).to eq("test")
    end

    context "with querying unexpected keys" do
      it "returns nil" do
        expect(filters[:unexpected]).to be_nil
      end
    end
  end
end
