# frozen_string_literal: true

class ValidateSubscriptionsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :subscriptions, :organizations
  end
end
