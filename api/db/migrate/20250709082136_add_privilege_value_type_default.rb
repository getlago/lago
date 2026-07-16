# frozen_string_literal: true

class AddPrivilegeValueTypeDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :entitlement_privileges, :value_type, from: nil, to: "string"
  end
end
