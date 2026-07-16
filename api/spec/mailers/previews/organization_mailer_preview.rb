# frozen_string_literal: true

class OrganizationMailerPreview < BasePreviewMailer
  def authentication_methods_updated
    organization = Organization.first
    user = organization.admins.first
    additions = Organization::PREMIUM_AUTHENTICATION_METHODS
    deletions = Organization::FREE_AUTHENTICATION_METHODS

    OrganizationMailer.with(organization:, user:, additions:, deletions:).authentication_methods_updated
  end
end
