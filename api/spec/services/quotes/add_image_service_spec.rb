# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::AddImageService do
  subject(:service) { described_class.new(quote:, image:) }

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:quote) { create(:quote, organization:) }

  let(:png_bytes) { "\x89PNG\r\n\x1A\n".b }
  let(:image) { "data:image/png;base64,#{Base64.strict_encode64(png_bytes)}" }

  describe ".call" do
    let(:result) { service.call }

    context "with a valid image", :premium do
      it "attaches the image to the quote and returns its URL" do
        expect(result).to be_success
        expect(result.image_url).to include("/rails/active_storage/blobs")

        expect(quote.reload.images.count).to eq(1)
        expect(result.image_id).to eq(quote.images.first.blob.id)
        expect(quote.images.first.content_type).to eq("image/png")
        expect(quote.images.first.filename.to_s).to end_with(".png")
      end
    end

    context "when quote does not exist", :premium do
      let(:quote) { nil }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("quote_not_found")
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "when order_forms feature is disabled", :premium do
      let(:organization) { create(:organization) }

      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "when the image is malformed", :premium do
      let(:image) { "not-a-data-uri" }

      it "returns a validation failure without attaching" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:image]).to eq(["invalid_format"])
        expect(quote.reload.images).not_to be_attached
      end
    end

    context "when the image type is unsupported", :premium do
      let(:image) { "data:application/pdf;base64,#{Base64.strict_encode64("%PDF-1.4")}" }

      it "returns a validation failure without attaching" do
        expect { result }.to have_enqueued_job(ActiveStorage::PurgeJob)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:image]).to eq(["invalid_content_type"])
        expect(quote.reload.images).not_to be_attached
      end
    end

    context "when the image exceeds the max size", :premium do
      before do
        io = StringIO.new(png_bytes)
        allow(io).to receive(:size).and_return(6.megabytes)
        decoded = Utils::Base64File::Decoded.new(io:, content_type: "image/png")
        allow(Utils::Base64File).to receive(:decode).and_return(decoded)
        allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_call_original
      end

      it "returns a validation failure without uploading to storage" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:image]).to eq(["file_too_large"])
        expect(quote.reload.images).not_to be_attached
        expect(ActiveStorage::Blob).not_to have_received(:create_and_upload!)
      end
    end
  end
end
