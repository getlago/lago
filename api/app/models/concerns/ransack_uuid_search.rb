# frozen_string_literal: true

module RansackUuidSearch
  extend ActiveSupport::Concern

  included do
    ransacker :id do
      Arel.sql("\"#{table_name}\".\"id\"::varchar")
    end

    ransacker :object_id do
      Arel.sql("\"#{table_name}\".\"object_id\"::varchar")
    end
  end
end
