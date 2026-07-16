# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Plans::MetadataController do
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }

  describe "POST /api/v1/plans/:code/metadata" do
    subject { post_with_token(organization, "/api/v1/plans/#{plan_code}/metadata", {metadata: params}) }

    let(:plan_code) { plan.code }
    let(:params) { {foo: "bar", baz: "qux"} }

    it_behaves_like "requires API permission", "plan", "write"

    context "when plan is not found" do
      let(:plan_code) { "invalid_code" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("plan")
      end
    end

    context "when plan has no metadata" do
      it "creates metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
        expect(plan.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
      end
    end

    context "when plan has existing metadata" do
      before { create(:item_metadata, owner: plan, organization:, value: {old: "value", foo: "old"}) }

      it "replaces all metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
        expect(plan.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
      end
    end

    context "when params are empty" do
      let(:params) { {} }

      before { create(:item_metadata, owner: plan, organization:, value: {old: "value"}) }

      it "replaces metadata with empty hash" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq({})
        expect(plan.reload.metadata.value).to eq({})
      end
    end

    context "when params are empty and metadata does not exist" do
      let(:params) { {} }

      it "creates metadata with empty hash" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq({})
        expect(plan.reload.metadata.value).to eq({})
      end
    end

    context "when metadata param is not provided" do
      subject { post_with_token(organization, "/api/v1/plans/#{plan_code}/metadata", {}) }

      it "does not create metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(nil)
        expect(plan.reload.metadata).to eq(nil)
      end
    end
  end

  describe "PATCH /api/v1/plans/:code/metadata" do
    subject { patch_with_token(organization, "/api/v1/plans/#{plan_code}/metadata", {metadata: params}) }

    let(:plan_code) { plan.code }
    let(:params) { {foo: "bar", baz: "qux"} }

    it_behaves_like "requires API permission", "plan", "write"

    context "when plan is not found" do
      let(:plan_code) { "invalid_code" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("plan")
      end
    end

    context "when plan has no metadata" do
      it "creates metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
        expect(plan.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
      end
    end

    context "when plan has existing metadata" do
      before { create(:item_metadata, owner: plan, organization:, value: {"old" => "value", "foo" => "old"}) }

      it "merges metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(old: "value", foo: "bar", baz: "qux")
        expect(plan.reload.metadata.value).to eq("old" => "value", "foo" => "bar", "baz" => "qux")
      end
    end

    context "when params are empty and metadata exists" do
      let(:params) { {} }

      before { create(:item_metadata, owner: plan, organization:, value: {"old" => "value"}) }

      it "keeps existing metadata unchanged" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(old: "value")
        expect(plan.reload.metadata.value).to eq("old" => "value")
      end
    end

    context "when params are empty and metadata does not exist" do
      let(:params) { {} }

      it "does not create metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to be_nil
        expect(plan.reload.metadata).to be_nil
      end
    end

    context "when metadata param is not provided" do
      subject { patch_with_token(organization, "/api/v1/plans/#{plan_code}/metadata", {}) }

      it "does not create metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to be_nil
        expect(plan.reload.metadata).to be_nil
      end
    end
  end

  describe "DELETE /api/v1/plans/:code/metadata" do
    subject { delete_with_token(organization, "/api/v1/plans/#{plan_code}/metadata") }

    let(:plan_code) { plan.code }

    it_behaves_like "requires API permission", "plan", "write"

    context "when plan is not found" do
      let(:plan_code) { "invalid_code" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("plan")
      end
    end

    context "when plan has metadata" do
      before { create(:item_metadata, owner: plan, organization:, value: {"foo" => "bar"}) }

      it "deletes all metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to be_nil
        expect(plan.reload.metadata).to be_nil
      end
    end

    context "when plan has no metadata" do
      it "returns success with nil metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to be_nil
        expect(plan.reload.metadata).to be_nil
      end
    end
  end

  describe "DELETE /api/v1/plans/:code/metadata/:key" do
    subject { delete_with_token(organization, "/api/v1/plans/#{plan_code}/metadata/#{key}") }

    let(:plan_code) { plan.code }
    let(:key) { "foo" }

    it_behaves_like "requires API permission", "plan", "write"

    context "when plan is not found" do
      let(:plan_code) { "invalid_code" }

      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("plan")
      end
    end

    context "when plan has no metadata" do
      it "returns not found error" do
        subject
        expect(response).to be_not_found_error("metadata")
      end
    end

    context "when key exists in metadata" do
      before { create(:item_metadata, owner: plan, organization:, value: {"foo" => "bar", "baz" => "qux"}) }

      it "deletes the key" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(baz: "qux")
        expect(plan.reload.metadata.value).to eq("baz" => "qux")
      end
    end

    context "when key does not exist in metadata" do
      before { create(:item_metadata, owner: plan, organization:, value: {"baz" => "qux"}) }

      it "returns success without changing metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(baz: "qux")
        expect(plan.reload.metadata.value).to eq("baz" => "qux")
      end
    end
  end
end
