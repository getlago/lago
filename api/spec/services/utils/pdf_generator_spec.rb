# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::PdfGenerator do
  subject(:pdf_generator_service) { described_class.new(template: "invoices/v2", context: invoice) }

  let(:invoice) { create(:invoice) }
  let(:pdf_response) do
    File.read(Rails.root.join("spec/fixtures/blank.pdf"))
  end

  before do
    stub_request(:post, "#{ENV["LAGO_PDF_URL"]}/forms/chromium/convert/html")
      .to_return(body: pdf_response, status: 200)
  end

  describe ".call" do
    it "generated the document synchronously" do
      result = pdf_generator_service.call

      expect(result.io).to be_present
    end
  end
end
