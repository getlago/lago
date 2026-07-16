# frozen_string_literal: true

require "rails_helper"

RSpec.describe BaseResult do
  subject(:result) { described_class.new }

  it_behaves_like "a result object"

  describe "#[]" do
    let(:result_class) { described_class[:property] }

    it { expect(result_class.new).to be_a(described_class) }

    it "defines the attributes" do
      expect(result_class.new).to respond_to(:property)
      expect(result_class.new).to respond_to(:property=)
    end

    context "with multiple properties" do
      let(:result_class) { described_class[:property, :another_property] }

      it "defines the attributes" do
        expect(result_class.new).to respond_to(:property)
        expect(result_class.new).to respond_to(:property=)
        expect(result_class.new).to respond_to(:another_property)
        expect(result_class.new).to respond_to(:another_property=)
      end
    end
  end

  describe ".==" do
    subject(:result) { result_class.new.tap { it.property = "value" } }

    let(:result_class) { described_class[:property] }
    let(:other_result) { result_class.new.tap { it.property = "value" } }

    it { expect(result).to eq(other_result) }

    context "when the properties are different" do
      let(:other_result) { result_class.new.tap { it.property = "different_value" } }

      it { expect(result).not_to eq(other_result) }
    end

    context "when the properties are nil" do
      let(:other_result) { result_class.new }

      it { expect(result).not_to eq(other_result) }
    end

    context "when one result is a failure" do
      let(:other_result) { result_class.new.not_found_failure!(resource: "property") }

      it { expect(result).not_to eq(other_result) }
    end

    context "when results are the same failed result" do
      it "returns true" do
        expect(result.not_found_failure!(resource: "property"))
          .to eq(other_result.not_found_failure!(resource: "property"))
      end
    end

    context "when one result is an other failure" do
      let(:other_result) { result_class.new.not_found_failure!(resource: "property") }

      it { expect(result.not_found_failure!(resource: "values")).not_to eq(other_result) }
    end

    context "when one result is a different result class" do
      let(:other_result_class) { described_class[:another_property] }
      let(:other_result) { other_result_class.new.tap { it.another_property = "value" } }

      it { expect(result).not_to eq(other_result) }
    end
  end
end
