# frozen_string_literal: true

class UsersService < BaseService
  def login(email, password)
    # NOTE: Null byte injection. Prevent 500 errors.
    if email.include?("\u0000") || password.include?("\u0000")
      return result.single_validation_failure!(error_code: "incorrect_login_or_password")
    end

    result.user = User.find_by(email:)&.authenticate(password)

    unless result.user.present? && result.user.memberships.active.any?
      return result.single_validation_failure!(error_code: "incorrect_login_or_password")
    end

    unless result.user.active_organizations.pluck(:authentication_methods).flatten.uniq.include?(Organizations::AuthenticationMethods::EMAIL_PASSWORD)
      return result.single_validation_failure!(
        error_code: "login_method_not_authorized",
        field: Organizations::AuthenticationMethods::EMAIL_PASSWORD
      )
    end

    result.token = generate_token if result.user

    # NOTE: We're tracking the first membership linked to the user.
    membership = result.user.memberships.active.first
    SegmentIdentifyJob.perform_later(membership_id: "membership/#{membership.id}")

    UserDevices::RegisterService.call!(user: result.user)

    result
  end

  def register(email, password, organization_name)
    if ENV.fetch("LAGO_DISABLE_SIGNUP", "false") == "true"
      return result.not_allowed_failure!(code: "signup_disabled")
    end

    if User.exists?(email:)
      result.single_validation_failure!(field: :email, error_code: "user_already_exists")

      return result
    end

    ActiveRecord::Base.transaction do
      result.user = User.create!(email:, password:)

      result.organization = Organizations::CreateService
        .call!(name: organization_name, document_numbering: "per_organization")
        .organization

      result.membership = Membership.create!(
        user: result.user,
        organization: result.organization
      )

      MembershipRole.create!(
        organization: result.organization,
        membership: result.membership,
        role: Role.admins.first!
      )

      result.token = generate_token
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    SegmentIdentifyJob.perform_later(membership_id: "membership/#{result.membership.id}")
    track_organization_registered(result.organization, result.membership)

    register_security_log(result)

    # Skip log: user.signed_up already covers signup
    UserDevices::RegisterService.call!(user: result.user, skip_log: true)

    result
  end

  def register_from_invite(invite, password)
    ActiveRecord::Base.transaction do
      user = User.find_or_initialize_by(email: invite.email)

      if user.new_record?
        user.password = password
        user.save!
      elsif user.memberships.active.none?
        user.update!(password:)
      end

      result.user = user
      result.organization = invite.organization

      result.membership = Membership.create!(
        user: result.user,
        organization: result.organization
      )

      invite.roles.each do |role_code|
        role = Role.with_code(role_code).with_organization(invite.organization_id).first!
        MembershipRole.create!(
          organization: result.organization,
          membership: result.membership,
          role:
        )
      end

      result.token = generate_token
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    result
  end

  private

  def generate_token
    Auth::TokenService.encode(user: result.user, login_method: Organizations::AuthenticationMethods::EMAIL_PASSWORD)
  rescue => e
    result.service_failure!(code: "token_encoding_error", message: e.message)
  end

  def track_organization_registered(organization, membership)
    SegmentTrackJob.perform_later(
      membership_id: "membership/#{membership.id}",
      event: "organization_registered",
      properties: {
        organization_name: organization.name,
        organization_id: organization.id,
        email: membership.user.email
      }
    )
  end

  def register_security_log(result)
    Utils::SecurityLog.produce(
      organization: result.organization,
      log_type: "user",
      log_event: "user.signed_up",
      user: result.user,
      resources: {
        email: result.user.email,
        roles: result.membership.roles.map(&:code)
      },
      skip_organization_check: true
    )
  end
end
