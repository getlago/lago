# frozen_string_literal: true

class AddAuditLogsPeriodToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations,
      :audit_logs_period,
      :integer,
      default: 30
  end
end
