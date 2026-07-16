# frozen_string_literal: true

class AddIncompletedAtToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :incompleted_at, :datetime
  end
end
