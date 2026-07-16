# frozen_string_literal: true

require "rails_helper"

# Tests for IntervalHelper placed under app/views/helpers as requested
RSpec.describe IntervalHelper do
  describe ".interval_name" do
    subject(:result) { described_class.interval_name(interval) }

    context "when interval is :weekly" do
      let(:interval) { :weekly }

      it "returns translation" do
        expect(subject).to eq("week")
      end
    end

    context "when interval is 'weekly'" do
      let(:interval) { "weekly" }

      it "returns translation" do
        expect(subject).to eq("week")
      end
    end

    context "when interval is :monthly" do
      let(:interval) { :monthly }

      it "returns translation" do
        expect(subject).to eq("month")
      end
    end

    context "when interval is 'monthly'" do
      let(:interval) { "monthly" }

      it "returns translation" do
        expect(subject).to eq("month")
      end
    end

    context "when interval is :yearly" do
      let(:interval) { :yearly }

      it "returns translation" do
        expect(subject).to eq("year")
      end
    end

    context "when interval is 'yearly'" do
      let(:interval) { "yearly" }

      it "returns translation" do
        expect(subject).to eq("year")
      end
    end

    context "when interval is :quarterly" do
      let(:interval) { :quarterly }

      it "returns translation" do
        expect(subject).to eq("quarter")
      end
    end

    context "when interval is 'quarterly'" do
      let(:interval) { "quarterly" }

      it "returns translation" do
        expect(subject).to eq("quarter")
      end
    end

    context "when interval is :semiannual" do
      let(:interval) { :semiannual }

      it "returns translation" do
        expect(subject).to eq("half-year")
      end
    end

    context "when interval is 'semiannual'" do
      let(:interval) { "semiannual" }

      it "returns translation" do
        expect(subject).to eq("half-year")
      end
    end

    context "when interval is unknown" do
      let(:interval) { :daily }

      it "returns nil and does not translate" do
        expect(subject).to be_nil
      end
    end
  end
end
