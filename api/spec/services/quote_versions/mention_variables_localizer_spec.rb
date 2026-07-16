# frozen_string_literal: true

require "rails_helper"

RSpec.describe QuoteVersions::MentionVariablesLocalizer do
  describe ".call" do
    subject(:localized) { described_class.call(mention_variables:, locale:) }

    let(:locale) { :en }

    context "with date variables" do
      let(:mention_variables) do
        {"quote_date" => "2026-04-01", "commercial_terms_start_date" => "2026-04-01"}
      end

      it "formats dates for the locale" do
        expect(localized).to eq(
          "quote_date" => "Apr 01, 2026",
          "commercial_terms_start_date" => "Apr 01, 2026"
        )
      end

      context "when the locale is French" do
        let(:locale) { :fr }

        it "formats dates in French" do
          expect(localized).to eq(
            "quote_date" => "1 avr. 2026",
            "commercial_terms_start_date" => "1 avr. 2026"
          )
        end
      end
    end

    context "with a term duration" do
      let(:mention_variables) { {"commercial_terms_term_duration" => {"unit" => "years", "count" => 1}} }

      it "translates the duration" do
        expect(localized).to eq("commercial_terms_term_duration" => "1 year")
      end

      context "when the locale is French" do
        let(:locale) { :fr }

        it "translates the duration in French" do
          expect(localized).to eq("commercial_terms_term_duration" => "un an")
        end
      end
    end

    context "with payment terms" do
      let(:mention_variables) { {"commercial_terms_payment_terms" => 30} }

      it "translates the payment terms" do
        expect(localized).to eq("commercial_terms_payment_terms" => "Net 30")
      end
    end

    context "with a billing address" do
      let(:mention_variables) do
        {
          "billing_entity_address" => {
            "address_line1" => "4 rue de la Paix",
            "address_line2" => nil,
            "locality" => "Paris",
            "postal_code" => "75002",
            "administrative_area" => nil,
            "country_code" => "FR"
          }
        }
      end

      it "formats the address" do
        expect(localized).to eq("billing_entity_address" => "4 rue de la Paix\n75002 Paris\nFrance")
      end
    end

    context "with locale-independent values" do
      let(:mention_variables) { {"customer_name" => "Hooli Inc - Gavin Belson", "quote_currency" => "EUR"} }

      it "passes them through unchanged" do
        expect(localized).to eq("customer_name" => "Hooli Inc - Gavin Belson", "quote_currency" => "EUR")
      end
    end

    context "with a partial dictionary" do
      let(:mention_variables) { {"customer_name" => "Hooli Inc - Gavin Belson"} }

      it "only returns the keys present" do
        expect(localized).to eq("customer_name" => "Hooli Inc - Gavin Belson")
      end
    end

    context "with blank locale-sensitive values" do
      let(:mention_variables) do
        {
          "commercial_terms_start_date" => nil,
          "commercial_terms_term_duration" => nil,
          "commercial_terms_payment_terms" => nil,
          "billing_entity_address" => nil
        }
      end

      it "renders them as nil" do
        expect(localized).to eq(
          "commercial_terms_start_date" => nil,
          "commercial_terms_term_duration" => nil,
          "commercial_terms_payment_terms" => nil,
          "billing_entity_address" => nil
        )
      end
    end
  end
end
