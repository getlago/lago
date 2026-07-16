# frozen_string_literal: true

class AddActivatedAtToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :activated_at, :datetime
  end
end
