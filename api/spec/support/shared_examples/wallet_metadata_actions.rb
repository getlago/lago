# frozen_string_literal: true

RSpec.shared_examples "a wallet metadata create endpoint" do
  let(:params) { {foo: "bar", baz: "qux"} }
  let(:metadata_params) { {metadata: params} }

  it_behaves_like "requires API permission", "wallet", "write"

  context "when wallet is not found" do
    let(:wallet_id) { "invalid_id" }

    it "returns not found error" do
      subject
      expect(response).to be_not_found_error("wallet")
    end
  end

  context "when wallet has no metadata" do
    it "creates metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
      expect(wallet.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
    end
  end

  context "when wallet has existing metadata" do
    before { create(:item_metadata, owner: wallet, organization:, value: {old: "value", foo: "old"}) }

    it "replaces all metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
      expect(wallet.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
    end
  end

  context "when params are empty" do
    let(:params) { {} }

    before { create(:item_metadata, owner: wallet, organization:, value: {old: "value"}) }

    it "replaces metadata with empty hash" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq({})
      expect(wallet.reload.metadata.value).to eq({})
    end
  end

  context "when params are empty and metadata does not exist" do
    let(:params) { {} }

    it "creates metadata with empty hash" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq({})
      expect(wallet.reload.metadata.value).to eq({})
    end
  end

  context "when metadata param is not provided" do
    let(:metadata_params) { {} }

    it "does not create empty metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq(nil)
      expect(wallet.reload.metadata).to eq(nil)
    end
  end
end

RSpec.shared_examples "a wallet metadata update endpoint" do
  let(:params) { {foo: "bar", baz: "qux"} }
  let(:metadata_params) { {metadata: params} }

  it_behaves_like "requires API permission", "wallet", "write"

  context "when wallet is not found" do
    let(:wallet_id) { "invalid_id" }

    it "returns not found error" do
      subject
      expect(response).to be_not_found_error("wallet")
    end
  end

  context "when wallet has no metadata" do
    it "creates metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq(foo: "bar", baz: "qux")
      expect(wallet.reload.metadata.value).to eq("foo" => "bar", "baz" => "qux")
    end
  end

  context "when wallet has existing metadata" do
    before { create(:item_metadata, owner: wallet, organization:, value: {"old" => "value", "foo" => "old"}) }

    it "merges metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq(old: "value", foo: "bar", baz: "qux")
      expect(wallet.reload.metadata.value).to eq("old" => "value", "foo" => "bar", "baz" => "qux")
    end
  end

  context "when params are empty and metadata exists" do
    let(:params) { {} }

    before { create(:item_metadata, owner: wallet, organization:, value: {"old" => "value"}) }

    it "keeps existing metadata unchanged" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq(old: "value")
      expect(wallet.reload.metadata.value).to eq("old" => "value")
    end
  end

  context "when params are empty and metadata does not exist" do
    let(:params) { {} }

    it "does not create metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to be_nil
      expect(wallet.reload.metadata).to be_nil
    end
  end

  context "when metadata param is not provided" do
    let(:metadata_params) { {} }

    it "does not create metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to be_nil
      expect(wallet.reload.metadata).to be_nil
    end

    context "when metadata existed before" do
      before { create(:item_metadata, owner: wallet, organization:, value: {"old" => "value"}) }

      it "keeps existing metadata unchanged" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:metadata]).to eq(old: "value")
        expect(wallet.reload.metadata.value).to eq("old" => "value")
      end
    end
  end
end

RSpec.shared_examples "a wallet metadata destroy endpoint" do
  it_behaves_like "requires API permission", "wallet", "write"

  context "when wallet is not found" do
    let(:wallet_id) { "invalid_id" }

    it "returns not found error" do
      subject
      expect(response).to be_not_found_error("wallet")
    end
  end

  context "when wallet has metadata" do
    before { create(:item_metadata, owner: wallet, organization:, value: {"foo" => "bar"}) }

    it "deletes all metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to be_nil
      expect(wallet.reload.metadata).to be_nil
    end
  end

  context "when wallet has no metadata" do
    it "returns success with nil metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to be_nil
      expect(wallet.reload.metadata).to be_nil
    end
  end
end

RSpec.shared_examples "a wallet metadata destroy key endpoint" do
  let(:key) { "foo" }

  it_behaves_like "requires API permission", "wallet", "write"

  context "when wallet is not found" do
    let(:wallet_id) { "invalid_id" }

    it "returns not found error" do
      subject
      expect(response).to be_not_found_error("wallet")
    end
  end

  context "when wallet has no metadata" do
    it "returns not found error" do
      subject
      expect(response).to be_not_found_error("metadata")
    end
  end

  context "when key exists in metadata" do
    before { create(:item_metadata, owner: wallet, organization:, value: {"foo" => "bar", "baz" => "qux"}) }

    it "deletes the key" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq(baz: "qux")
      expect(wallet.reload.metadata.value).to eq("baz" => "qux")
    end
  end

  context "when key does not exist in metadata" do
    before { create(:item_metadata, owner: wallet, organization:, value: {"baz" => "qux"}) }

    it "returns success without changing metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:metadata]).to eq(baz: "qux")
      expect(wallet.reload.metadata.value).to eq("baz" => "qux")
    end
  end
end
