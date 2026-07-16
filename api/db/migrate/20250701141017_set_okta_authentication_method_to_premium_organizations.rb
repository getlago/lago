# frozen_string_literal: true

class SetOktaAuthenticationMethodToPremiumOrganizations < ActiveRecord::Migration[8.0]
  # rubocop:disable Rails/SkipsModelValidations
  def change
    Organization.with_okta_support.update_all("authentication_methods = ARRAY['email_password', 'google_oauth', 'okta']")
  end
  # rubocop:enable Rails/SkipsModelValidations
end
