# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhook do
  subject(:webhook) { build(:webhook) }

  it { is_expected.to belong_to(:webhook_endpoint) }
  it { is_expected.to belong_to(:object).optional }
  it { is_expected.to belong_to(:organization) }

  describe "#payload" do
    subject { webhook.payload }

    let(:webhook) { create(:webhook, payload:) }
    let(:original_payload) { Faker::Types.rb_hash(number: 3).stringify_keys }

    context "when payload stored as string" do
      let(:payload) { original_payload.to_json }

      it "returns payload as hash" do
        expect(subject).to eq(original_payload)
      end
    end

    context "when payload stored as hash" do
      let(:payload) { original_payload }

      it "returns payload as hash" do
        expect(subject).to eq(original_payload)
      end
    end

    context "when payload stored on object storage" do
      let(:webhook) { create(:webhook, payload: nil) }

      before do
        webhook.store_payload(original_payload)
        webhook.save!
      end

      it "returns the payload read from object storage" do
        expect(described_class.find(webhook.id).payload).to eq(original_payload)
      end
    end
  end

  describe "#response" do
    subject { webhook.response }

    context "when response stored on object storage" do
      let(:webhook) { create(:webhook, response: nil) }
      let(:original_response) { {"status" => "ok"} }

      before do
        webhook.store_response(original_response)
        webhook.save!
      end

      it "returns the response read from object storage" do
        expect(described_class.find(webhook.id).response).to eq(original_response)
      end
    end

    context "when response stored in the database" do
      let(:webhook) { create(:webhook, :failed) }

      it "returns the response from the database" do
        expect(subject).to eq(webhook.read_attribute(:response))
      end
    end
  end

  describe "#store_payload" do
    subject(:webhook) { create(:webhook, payload: nil) }

    let(:content) { {"foo" => "bar"} }

    it "uploads the gzipped payload to object storage and stores the key" do
      key = webhook.store_payload(content)

      expect(key).to match(%r{\Awebhooks/\d{4}/\d{2}/\d{2}/[0-9a-f-]+/payload\.json\.gz\z})
      expect(webhook.payload_key).to eq(key)
      expect(ActiveSupport::Gzip.decompress(described_class.payload_storage.download(key))).to eq(content.to_json)
    end

    it "does not store the payload in the database" do
      webhook.store_payload(content)
      webhook.save!

      expect(webhook.reload.read_attribute(:payload)).to be_nil
      expect(webhook.payload).to eq(content)
    end
  end

  describe "#store_response" do
    subject(:webhook) { create(:webhook, payload: nil) }

    let(:content) { {"status" => "ok"} }

    it "uploads the gzipped response alongside the payload and stores the key" do
      webhook.store_payload({"foo" => "bar"})
      key = webhook.store_response(content)

      expect(key).to match(%r{\Awebhooks/\d{4}/\d{2}/\d{2}/[0-9a-f-]+/response\.json\.gz\z})
      expect(File.dirname(key)).to eq(File.dirname(webhook.payload_key))
      expect(ActiveSupport::Gzip.decompress(described_class.payload_storage.download(key))).to eq(content.to_json)
    end

    it "does not store the response in the database" do
      webhook.store_response(content)
      webhook.save!

      expect(webhook.reload.read_attribute(:response)).to be_nil
      expect(webhook.response).to eq(content)
    end

    context "when the upload fails" do
      before do
        allow(described_class.payload_storage).to receive(:upload).and_raise(StandardError.new("boom"))
      end

      it "falls back to storing the response in the database" do
        webhook.store_response(content)
        webhook.save!

        expect(webhook.response_key).to be_nil
        expect(webhook.reload.read_attribute(:response)).to eq(content)
        expect(webhook.response).to eq(content)
      end
    end
  end

  describe "#generate_headers" do
    subject { webhook.generate_headers }

    let(:webhook) { create(:webhook, webhook_endpoint:) }
    let(:webhook_endpoint) { create(:webhook_endpoint, signature_algo:) }

    context "when signature algorithm is JWT" do
      let(:signature_algo) { :jwt }

      it "returns headers" do
        expect(subject).to eq(
          "X-Lago-Signature" => webhook.jwt_signature,
          "X-Lago-Signature-Algorithm" => "jwt",
          "X-Lago-Unique-Key" => webhook.id
        )
      end
    end

    context "when signature algorithm is HMAC" do
      let(:signature_algo) { :hmac }

      it "returns headers" do
        expect(subject).to eq(
          "X-Lago-Signature" => webhook.hmac_signature,
          "X-Lago-Signature-Algorithm" => "hmac",
          "X-Lago-Unique-Key" => webhook.id
        )
      end
    end
  end

  describe "#jwt_signature" do
    let(:decoded_signature) do
      JWT.decode(
        webhook.jwt_signature,
        RsaPublicKey,
        true,
        {
          algorithm: "RS256",
          iss: ENV["LAGO_API_URL"],
          verify_iss: true
        }
      )
    end

    let(:expected_signature) do
      [
        {"data" => webhook.payload.to_json, "iss" => "https://api.lago.dev"},
        {"alg" => "RS256"}
      ]
    end

    it "generates a correct jwt signature" do
      expect(decoded_signature).to eq expected_signature
    end
  end

  describe "#hmac_signature" do
    subject { webhook.hmac_signature }

    let(:webhook) { create(:webhook) }

    let(:expected_signature) do
      hmac = OpenSSL::HMAC.digest(
        "sha-256",
        webhook.organization.hmac_key,
        webhook.payload.to_json
      )

      Base64.strict_encode64(hmac)
    end

    it "returns HMAC signature as base 64 encoded string" do
      expect(subject).to eq expected_signature
    end
  end
end
