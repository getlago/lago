namespace :signup do
  desc "Create or update the organization admin user"
  task create_org_admin: :environment do
    organization = Organization.find_or_create_by!(name: ENV.fetch("LAGO_ORG_NAME", "Lago"))

    user = User.find_or_initialize_by(email: ENV["LAGO_ORG_USER_EMAIL"])
    user.password = ENV["LAGO_ORG_USER_PASSWORD"]
    user.save!

    user.memberships.find_or_create_by!(organization: organization, role: :admin)
  end
end
