# frozen_string_literal: true

class AddMentionVariablesToQuoteVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :quote_versions, :mention_variables, :jsonb
  end
end
