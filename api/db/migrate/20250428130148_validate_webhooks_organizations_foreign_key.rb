# frozen_string_literal: true

class ValidateWebhooksOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :webhooks, :organizations
  end
end
