# frozen_string_literal: true

RSpec.describe Common do
  let(:controller) { klass.new }

  let(:klass) do
    Class.new do
      include Common

      public :valid_date? # expose for testing
    end
  end

  describe "#valid_date?" do
    subject(:method_call) { controller.valid_date?(date) }

    context "when date is nil" do
      let(:date) { nil }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when date is empty string" do
      let(:date) { "" }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when a valid date string is provided" do
      let(:date) { "2021-01-01" }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "when an invalid date string is provided" do
      let(:date) { "2021-02-30" }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when a malformed date sis provided" do
      let(:date) { "not-a-date" }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when a malformed date raises a bare ArgumentError" do
      let(:date) { "1" * 129 }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end
end
