# frozen_string_literal: true

class RemoveEventIdFromCachedAggregation < ActiveRecord::Migration[8.0]
  def up
    # This migration has been removed to allow safe upgrade for self hosted instances
    # It will be replaced with an other migration after a first phase of cleanup to make sure that no
    # code relies on the event_id column anymore
    unless Rails.env.production?
      safety_assured do
        remove_column :cached_aggregations, :event_id
      end
    end
  end
end
