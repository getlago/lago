# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::BaseController, type: :controller do
  controller do
    def index
      render nothing: true
    end
  end

  before do
    allow(CurrentContext).to receive(:source=)
    allow(CurrentContext).to receive(:api_key_id=)
    allow(CurrentContext).to receive(:email=)
  end

  describe "#authenticate" do
    context "with valid X-Data-API-Key header" do
      before do
        stub_const("ENV", ENV.to_hash.merge("LAGO_DATA_API_BEARER_TOKEN" => "test_api_key"))
        request.headers["X-Data-API-Key"] = "test_api_key"
        get :index
      end

      it "returns success response" do
        expect(response).to have_http_status(:success)
      end

      it "sets current context email to nil" do
        expect(CurrentContext).to have_received(:email=).with(nil)
      end
    end

    context "with missing X-Data-API-Key header" do
      before do
        stub_const("ENV", ENV.to_hash.merge("LAGO_DATA_API_BEARER_TOKEN" => "test_api_key"))
        get :index
      end

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid X-Data-API-Key header" do
      before do
        stub_const("ENV", ENV.to_hash.merge("LAGO_DATA_API_BEARER_TOKEN" => "test_api_key"))
        request.headers["X-Data-API-Key"] = "invalid_key"
        get :index
      end

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when LAGO_DATA_API_BEARER_TOKEN is not set" do
      before do
        stub_const("ENV", ENV.to_hash.merge("LAGO_DATA_API_BEARER_TOKEN" => nil))
        request.headers["X-Data-API-Key"] = "test_api_key"
        get :index
      end

      it "returns unauthorized status" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "#set_context_source" do
    before do
      stub_const("ENV", ENV.to_hash.merge("LAGO_DATA_API_BEARER_TOKEN" => "test_api_key"))
      request.headers["X-Data-API-Key"] = "test_api_key"
      get :index
    end

    it "sets the context source to data" do
      expect(CurrentContext).to have_received(:source=).with("data")
    end

    it "sets the api_key_id to nil" do
      expect(CurrentContext).to have_received(:api_key_id=).with(nil)
    end
  end
end
