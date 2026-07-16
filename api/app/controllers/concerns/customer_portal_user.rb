# frozen_string_literal: true

module CustomerPortalUser
  extend ActiveSupport::Concern

  def customer_portal_user
    return unless customer_portal_token

    public_authenticator = ActiveSupport::MessageVerifier.new(ENV["SECRET_KEY_BASE"])
    id = public_authenticator.verify(customer_portal_token)

    @customer_portal_user ||= Customer.find_by(id:)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  private

  def customer_portal_token
    request.headers["customer-portal-token"]
  end
end
