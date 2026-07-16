# frozen_string_literal: true

module Admin
  class MembershipsController < BaseController
    def create
      result = ::Memberships::CreateService.call(user:, organization:)

      return render_error_response(result) unless result.success?

      render(
        json: ::V1::MembershipSerializer.new(
          result.membership,
          root_name: "membership"
        )
      )
    end

    private

    def user
      @user ||= User.find_by(id: params[:user_id])
    end

    def organization
      @organization ||= Organization.find_by(id: params[:organization_id])
    end
  end
end
