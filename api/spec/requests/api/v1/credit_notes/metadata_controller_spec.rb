# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::CreditNotes::MetadataController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:credit_note) { create(:credit_note, customer:) }

  describe "POST /api/v1/credit_notes/:id/metadata" do
    subject { post_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/metadata", {metadata: params}) }

    let(:credit_note_id) { credit_note.id }
    let(:params) { {foo: "bar", baz: "qux"} }

    it_behaves_like "requires API permission", "credit_note", "write"

    context "when credit note is not found" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("credit_note")
      end
    end

    context "when credit note is draft" do
      let(:credit_note) { create(:credit_note, :draft, customer:) }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("credit_note")
      end
    end

    context "when credit note has no metadata" do
      it "creates metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
        expect(credit_note.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
      end
    end

    context "when credit note has existing metadata" do
      before { create(:item_metadata, owner: credit_note, organization:, value: {old: "value", foo: "old"}) }

      it "replaces all metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
        expect(credit_note.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
      end
    end

    context "when params are empty" do
      let(:params) { {} }

      before { create(:item_metadata, owner: credit_note, organization:, value: {old: "value"}) }

      it "replaces metadata with empty hash" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq({})
        expect(credit_note.reload.metadata.value).to eq({})
      end
    end

    context "when params are empty and metadata does not exist" do
      let(:params) { {} }

      it "creates metadata with empty hash" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq({})
        expect(credit_note.reload.metadata.value).to eq({})
      end
    end

    context "when metadata param is not provided" do
      subject { post_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/metadata", {}) }

      it "creates metadata with empty hash" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq({})
        expect(credit_note.reload.metadata.value).to eq({})
      end
    end
  end

  describe "PATCH /api/v1/credit_notes/:id/metadata" do
    subject { patch_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/metadata", {metadata: params}) }

    let(:credit_note_id) { credit_note.id }
    let(:params) { {foo: "bar", baz: "qux"} }

    it_behaves_like "requires API permission", "credit_note", "write"

    context "when credit note is not found" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("credit_note")
      end
    end

    context "when credit note has no metadata" do
      it "creates metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
        expect(credit_note.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
      end
    end

    context "when credit note has existing metadata" do
      before { create(:item_metadata, owner: credit_note, organization:, value: {"old" => "value", "foo" => "old"}) }

      it "merges metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(old: "value", foo: "bar", baz: "qux")
        expect(credit_note.reload.metadata.value).to eq("old" => "value", "foo" => "bar", "baz" => "qux")
      end
    end

    context "when params are empty and metadata exists" do
      let(:params) { {} }

      before { create(:item_metadata, owner: credit_note, organization:, value: {"old" => "value"}) }

      it "keeps existing metadata unchanged" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(old: "value")
        expect(credit_note.reload.metadata.value).to eq("old" => "value")
      end
    end

    context "when params are empty and metadata does not exist" do
      let(:params) { {} }

      it "does not create metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to be_nil
        expect(credit_note.reload.metadata).to be_nil
      end
    end

    context "when metadata param is not provided" do
      subject { patch_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/metadata", {}) }

      it "does not create metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to be_nil
        expect(credit_note.reload.metadata).to be_nil
      end
    end
  end

  describe "DELETE /api/v1/credit_notes/:id/metadata" do
    subject { delete_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/metadata") }

    let(:credit_note_id) { credit_note.id }

    it_behaves_like "requires API permission", "credit_note", "write"

    context "when credit note is not found" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("credit_note")
      end
    end

    context "when credit note has metadata" do
      before { create(:item_metadata, owner: credit_note, organization:, value: {"foo" => "bar"}) }

      it "deletes all metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to be_nil
        expect(credit_note.reload.metadata).to be_nil
      end
    end

    context "when credit note has no metadata" do
      it "returns success with nil metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to be_nil
        expect(credit_note.reload.metadata).to be_nil
      end
    end
  end

  describe "DELETE /api/v1/credit_notes/:id/metadata/:key" do
    subject { delete_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/metadata/#{key}") }

    let(:credit_note_id) { credit_note.id }
    let(:key) { "foo" }

    it_behaves_like "requires API permission", "credit_note", "write"

    context "when credit note is not found" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("credit_note")
      end
    end

    context "when credit note has no metadata" do
      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("metadata")
      end
    end

    context "when key exists in metadata" do
      before { create(:item_metadata, owner: credit_note, organization:, value: {"foo" => "bar", "baz" => "qux"}) }

      it "deletes the key" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(baz: "qux")
        expect(credit_note.reload.metadata.value).to eq("baz" => "qux")
      end
    end

    context "when key does not exist in metadata" do
      before { create(:item_metadata, owner: credit_note, organization:, value: {"baz" => "qux"}) }

      it "returns success without changing metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(baz: "qux")
        expect(credit_note.reload.metadata.value).to eq("baz" => "qux")
      end
    end
  end
end
