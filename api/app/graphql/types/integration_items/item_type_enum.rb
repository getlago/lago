# frozen_string_literal: true

module Types
  module IntegrationItems
    class ItemTypeEnum < Types::BaseEnum
      graphql_name "IntegrationItemTypeEnum"

      IntegrationItem::ITEM_TYPES.each do |type|
        value type
      end
    end
  end
end
