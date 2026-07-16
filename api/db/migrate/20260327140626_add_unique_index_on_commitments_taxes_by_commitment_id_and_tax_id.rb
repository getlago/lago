# frozen_string_literal: true

class AddUniqueIndexOnCommitmentsTaxesByCommitmentIdAndTaxId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :commitments_taxes, [:commitment_id, :tax_id], unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
