# frozen_string_literal: true

namespace :roles do
  desc "Seeds predefined roles (admin, finance, manager) for production deployment"
  task seed_predefined: :environment do
    Role.find_or_create_by!(code: "admin", organization_id: nil) do |role|
      role.admin = true
      role.name = "Admin"
      role.description = "Administrator having all permissions"
      role.permissions = []
    end

    Role.find_or_create_by!(code: "finance", organization_id: nil) do |role|
      role.admin = false
      role.name = "Finance"
      role.description = "Finance role with permissions to manage financial data"
      role.permissions = []
    end

    Role.find_or_create_by!(code: "manager", organization_id: nil) do |role|
      role.admin = false
      role.name = "Manager"
      role.description = "The predefined manager role"
      role.permissions = []
    end
  end
end
