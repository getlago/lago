# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Ubl::PaymentMeans do
  subject do
    xml_document(:ubl) do |xml|
      described_class.serialize(xml:, type:, amount:)
    end
  end

  let(:resource) { invoice }
  let(:invoice) { create(:invoice, currency: "USD") }
  let(:type) { described_class::STANDARD_PAYMENT }
  let(:amount) { Money.new(1000) }

  let(:root) { "//cac:PaymentMeans" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    context "when STANDARD" do
      let(:type) { described_class::STANDARD_PAYMENT }

      it "contains section name as comment" do
        expect(subject).to contains_xml_comment("Payment Means: Standard payment")
      end

      it "have the payment code and information" do
        expect(subject).to contains_xml_node("#{root}/cbc:PaymentMeansCode").with_value(type)
      end
    end

    context "when PREPAID" do
      let(:type) { described_class::PREPAID_PAYMENT }

      it "contains section name as comment" do
        expect(subject).to contains_xml_comment("Payment Means: Prepaid credits")
      end

      it "have the payment code and information" do
        expect(subject).to contains_xml_node("#{root}/cbc:PaymentMeansCode").with_value(type)
      end
    end

    context "when CREDIT_NOTE" do
      let(:type) { described_class::CREDIT_NOTE_PAYMENT }

      it "contains section name as comment" do
        expect(subject).to contains_xml_comment("Payment Means: Credit notes")
      end

      it "have the payment code and information" do
        expect(subject).to contains_xml_node("#{root}/cbc:PaymentMeansCode").with_value(type)
      end
    end
  end
end
