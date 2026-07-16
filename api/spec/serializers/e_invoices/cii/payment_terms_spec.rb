# frozen_string_literal: true

require "rails_helper"

RSpec.describe EInvoices::Cii::PaymentTerms do
  subject do
    xml_document(:cii) do |xml|
      described_class.serialize(xml:, due_date:, description:) do
      end
    end
  end

  let(:due_date) { "20250316".to_date }
  let(:description) { "This is just a description, I can write anything" }

  let(:root) { "//ram:SpecifiedTradePaymentTerms" }

  describe ".serialize" do
    it { is_expected.not_to be_nil }

    it "contains section name as comment" do
      expect(subject).to contains_xml_comment("Payment Terms")
    end

    it "have Description" do
      expect(subject).to contains_xml_node("#{root}/ram:Description")
        .with_value(description)
    end

    it "have DueDate" do
      expect(subject).to contains_xml_node("#{root}/ram:DueDateDateTime/udt:DateTimeString")
        .with_value("20250316")
        .with_attribute("format", 102)
    end
  end
end
