# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::BaseController, type: [:controller, :admin] do
  controller do
    def index
      render nothing: true
    end
  end

  describe "authenticate" do
    it "validates the organization api key" do
      request.headers["Authorization"] = "Bearer 123456"

      get :index

      expect(response).to have_http_status(:success)
    end

    context "without authentication header" do
      it "returns an authentication error" do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
