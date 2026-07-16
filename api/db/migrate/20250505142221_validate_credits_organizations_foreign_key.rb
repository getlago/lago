# frozen_string_literal: true

class ValidateCreditsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :credits, :organizations
  end
end
