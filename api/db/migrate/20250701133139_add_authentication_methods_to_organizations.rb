# frozen_string_literal: true

class AddAuthenticationMethodsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations,
      :authentication_methods,
      :string,
      array: true,
      null: false,
      default: %w[email_password google_oauth]
  end
end
