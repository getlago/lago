# frozen_string_literal: true

class CreateAiConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_conversations, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :membership, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false
      t.string :mistral_conversation_id
      t.timestamps
    end
  end
end
