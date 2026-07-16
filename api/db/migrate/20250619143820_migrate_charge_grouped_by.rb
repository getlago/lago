# frozen_string_literal: true

class MigrateChargeGroupedBy < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute <<-SQL
        UPDATE charges
        SET properties = properties - 'grouped_by' || jsonb_build_object('pricing_group_keys', properties->'grouped_by')
        WHERE properties->'grouped_by' IS NOT NULL
          AND properties->'pricing_group_keys' IS NULL;
      SQL
    end
  end

  def down
  end
end
