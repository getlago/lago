# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationController do
  describe "GET /health" do
    it "returns the application health check" do
      get "/health"

      expect(response.status).to be(200)
      expect(json[:message]).to eq("Success")
      expect(json[:version]).to be_present
      expect(json[:github_url]).to be_present
    end
  end

  describe "Missing resources" do
    it "returns a 404 response" do
      get "/not_found"
      expect(response).to be_not_found_error("resource")
    end
  end
end
