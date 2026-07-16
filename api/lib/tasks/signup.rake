# frozen_string_literal: true

namespace :signup do
  desc "This task seeds lago with an organisation & a user for on premise deployment"
  task seed_organization: :environment do
    if ENV["LAGO_CREATE_ORG"].present? && ENV["LAGO_CREATE_ORG"] == "true"
      pp "starting seeding environment"
      unless ENV["LAGO_ORG_USER_PASSWORD"].present? &&
          ENV["LAGO_ORG_USER_EMAIL"].present? &&
          ENV["LAGO_ORG_NAME"].present?
        raise "Couldn't find LAGO_ORG_USER_PASSWORD, LAGO_ORG_USER_EMAIL or LAGO_ORG_NAME in environement variables"
      end

      user = User.create_with(password: ENV["LAGO_ORG_USER_PASSWORD"])
        .find_or_create_by!(email: ENV["LAGO_ORG_USER_EMAIL"])
      organization = Organization.find_or_create_by!(name: ENV["LAGO_ORG_NAME"])

      BillingEntity.find_or_create_by!(
        id: organization.id, organization:, name: organization.name, code: organization.name.parameterize
      )

      admin_role = Role.find_or_create_by!(admin: true)
      membership = Membership.find_or_create_by!(user:, organization:)
      MembershipRole.find_or_create_by!(membership:, organization:, role: admin_role)

      if ENV["LAGO_ORG_API_KEY"].present?
        api_key = ApiKey.find_or_create_by!(organization:, value: ENV["LAGO_ORG_API_KEY"])
        api_key.update!(value: ENV["LAGO_ORG_API_KEY"])
      else
        ApiKey.find_or_create_by!(organization:)
      end

      pp "ending seeding environment"
    end
  end
end
