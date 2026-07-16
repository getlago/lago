# frozen_string_literal: true

module Trackable
  extend ActiveSupport::Concern

  included do
    before_action :set_tracing_information
  end

  def set_tracing_information
    CurrentContext.membership = "membership/#{membership_id || "unidentifiable"}"
  end

  def membership_id
    return nil unless current_organization

    # NOTE: When doing requests from the API, we haven't the current user information.
    # In that case, we add tracing information on the first created membership of the organization.
    return first_membership_id unless defined?(current_user) && current_user

    current_organization.memberships.find_by(user_id: current_user.id).id
  end

  def first_membership_id
    @first_membership_id ||= current_organization.memberships.order(:created_at).first&.id
  end
end
