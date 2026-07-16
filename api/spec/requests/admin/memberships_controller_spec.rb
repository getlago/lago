# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::MembershipsController, type: [:request, :admin] do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }

  describe "POST /admin/memberships" do
    let(:create_params) do
      {
        user_id: user.id,
        organization_id: organization.id
      }
    end

    it "creates a membership" do
      admin_post(
        "/admin/memberships",
        create_params
      )

      expect(response).to have_http_status(:success)
      expect(json[:membership][:lago_user_id]).to eq(user.id)
      expect(json[:membership][:lago_organization_id]).to eq(organization.id)
    end
  end
end
