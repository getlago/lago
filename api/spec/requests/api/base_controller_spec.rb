# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::BaseController, type: :controller do
  controller do
    def index
      render nothing: true
    end

    def create
      params.require(:input).permit(:value)
      render nothing: true
    end

    def track_api_key_usage?
      action_name.to_sym != :create
    end
  end

  let(:api_key) { create(:api_key) }

  before do
    allow(CurrentContext).to receive(:source=)
    allow(CurrentContext).to receive(:api_key_id=)
  end

  it "sets the context source to api" do
    request.headers["Authorization"] = "Bearer #{api_key.value}"

    get :index

    expect(CurrentContext).to have_received(:source=).with("api")
    expect(CurrentContext).to have_received(:api_key_id=).with(api_key.id)
  end

  describe "#authenticate" do
    before do
      request.headers["Authorization"] = "Bearer #{api_key.value}"
      get :index
    end

    context "with valid authorization header" do
      let(:api_key) { [create(:api_key), create(:api_key, :expiring)].sample }

      it "returns success response" do
        expect(response).to have_http_status(:success)
      end
    end

    context "with invalid authentication header" do
      let(:api_key) { create(:api_key, :expired) }

      it "returns an authentication error" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "#track_api_key_usage", cache: :memory do
    let(:api_key) { create(:api_key) }
    let(:cache_key) { "api_key_last_used_#{api_key.id}" }

    before do
      request.headers["Authorization"] = "Bearer #{api_key.value}"
      freeze_time
    end

    context "when accessed trackable endpoint" do
      subject { get :index }

      it "caches when API key was last used" do
        expect { subject }.to change { Rails.cache.read(cache_key) }.to Time.current.iso8601
      end
    end

    context "when accessed non-trackable endpoint" do
      subject { get :create }

      it "does not cache when API key was last used" do
        expect { subject }.not_to change { Rails.cache.read(cache_key) }.from nil
      end
    end
  end

  it "catches the missing parameters error" do
    request.headers["Authorization"] = "Bearer #{api_key.value}"

    post :create

    expect(response).to have_http_status(:bad_request)

    json = JSON.parse(response.body, symbolize_names: true)
    expect(json[:status]).to eq(400)
    expect(json[:error]).to eq("BadRequest: param is missing or the value is empty or invalid: input")
  end
end
