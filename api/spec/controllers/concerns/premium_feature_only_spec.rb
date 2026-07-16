# frozen_string_literal: true

require "rails_helper"

RSpec.describe PremiumFeatureOnly do
  include ApiHelper

  # rubocop:disable RSpec/DescribedClass
  controller(ApplicationController) do
    include ApiErrors
    include PremiumFeatureOnly

    attr_reader :current_organization

    def index
      render json: {premium: "only"}
    end
  end
  # rubocop:enable RSpec/DescribedClass

  context "with free usage" do
    it "returns a forbidden error" do
      get :index

      expect(response).to have_http_status(:forbidden)
      expect(json[:error]).to eq("Forbidden")
      expect(json[:code]).to eq("feature_unavailable")
    end
  end

  context "when premium usage", :premium do
    it "does not block the request" do
      get :index

      expect(response).to have_http_status(:success)
      expect(json[:premium]).to eq("only")
    end
  end
end
