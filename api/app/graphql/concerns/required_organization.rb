# frozen_string_literal: true

module RequiredOrganization
  extend ActiveSupport::Concern

  private

  def ready?(**args)
    raise organization_error("Missing organization id") unless current_organization
    raise organization_error("Missing membership") unless current_membership
    raise organization_error("Not in organization") unless user_is_member_of_organization?

    super
  end

  def current_organization
    context[:current_organization]
  end

  def current_membership
    context[:current_membership]
  end

  def user_is_member_of_organization?
    return false unless context[:current_user]

    context[:current_user].id == current_membership.user_id && current_membership.organization_id == current_organization.id
  end

  def organization_error(message)
    GraphQL::ExecutionError.new(message, extensions: {status: :forbidden, code: "forbidden"})
  end
end
