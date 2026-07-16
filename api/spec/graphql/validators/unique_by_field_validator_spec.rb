# frozen_string_literal: true

require "rails_helper"

RSpec.describe Validators::UniqueByFieldValidator do
  subject(:validator) { described_class.new(field_name: :code, validated: validated_object) }

  let(:validated_object) { double("Validated Object") } # rubocop:disable RSpec/VerifiedDoubles
  let(:graphql_object) { double("GraphQL Object") } # rubocop:disable RSpec/VerifiedDoubles
  let(:context) { double("Context") } # rubocop:disable RSpec/VerifiedDoubles

  describe "#validate" do
    context "when there are no duplicates" do
      let(:value) { [{code: "USD"}, {code: "EUR"}, {code: "GBP"}] }

      it do
        expect(validator.validate(graphql_object, context, value)).to be_nil
      end
    end

    context "when there are duplicates" do
      let(:value) { [{code: "USD"}, {code: "EUR"}, {code: "USD"}] }

      it "returns duplicated_field error" do
        expect(validator.validate(graphql_object, context, value)).to eq("duplicated_field")
      end
    end

    context "when there are multiple different duplicates" do
      let(:value) do
        [
          {code: "USD"},
          {code: "EUR"},
          {code: "USD"},
          {code: "GBP"},
          {code: "EUR"}
        ]
      end

      it "returns duplicated_field error" do
        expect(validator.validate(graphql_object, context, value)).to eq("duplicated_field")
      end
    end

    context "when the value array is empty" do
      let(:value) { [] }

      it do
        expect(validator.validate(graphql_object, context, value)).to be_nil
      end
    end

    context "when there is only one item" do
      let(:value) { [{code: "USD"}] }

      it do
        expect(validator.validate(graphql_object, context, value)).to be_nil
      end
    end

    context "with custom field_name" do
      subject(:validator) { described_class.new(field_name: :currency_code, validated: validated_object) }

      context "when there are no duplicates" do
        let(:value) { [{currency_code: "USD"}, {currency_code: "EUR"}] }

        it do
          expect(validator.validate(graphql_object, context, value)).to be_nil
        end
      end

      context "when there are duplicates" do
        let(:value) { [{currency_code: "USD"}, {currency_code: "USD"}] }

        it "returns duplicated_field error" do
          expect(validator.validate(graphql_object, context, value)).to eq("duplicated_field")
        end
      end
    end

    context "when field values are nil" do
      let(:value) { [{code: "USD"}, {code: nil}, {code: nil}] }

      it do
        expect(validator.validate(graphql_object, context, value)).to be_nil
      end
    end

    context "when field values are strings and symbols" do
      let(:value) { [{code: "USD"}, {code: :USD}] }

      it "treats them as different values" do
        expect(validator.validate(graphql_object, context, value)).to be_nil
      end
    end
  end
end
