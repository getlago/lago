# frozen_string_literal: true

module Types
  module Organizations
    class EventsStoreEnum < Types::BaseEnum
      description "Organization events store values"

      Organization::EVENTS_STORES.values.each do |store|
        value store, description: "#{store.capitalize} events store"
      end
    end
  end
end
