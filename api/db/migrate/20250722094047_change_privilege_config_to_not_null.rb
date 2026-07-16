# frozen_string_literal: true

class ChangePrivilegeConfigToNotNull < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      change_column_null :entitlement_privileges, :config, false
    end
  end
end
