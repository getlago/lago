# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::Base64File do
  describe ".decode" do
    subject(:decoded) { described_class.decode(data_uri) }

    let(:content) { "hello world" }
    let(:data_uri) { "data:application/pdf;base64,#{Base64.strict_encode64(content)}" }

    it "extracts the declared content type from the data URI" do
      expect(decoded.content_type).to eq("application/pdf")
    end

    it "decodes the payload into a readable io" do
      expect(decoded.io.read).to eq(content)
    end

    context "with a different declared mime type" do
      let(:data_uri) { "data:image/png;base64,#{Base64.strict_encode64(content)}" }

      it "returns that content type" do
        expect(decoded.content_type).to eq("image/png")
      end
    end

    context "when the data URI has no comma" do
      let(:data_uri) { "not-a-data-uri" }

      it "returns nil" do
        expect(decoded).to be_nil
      end
    end

    context "when the metadata carries no content type" do
      let(:data_uri) { "base64,#{Base64.strict_encode64(content)}" }

      it "returns nil" do
        expect(decoded).to be_nil
      end
    end
  end
end
