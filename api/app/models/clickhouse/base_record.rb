# frozen_string_literal: true

module Clickhouse
  class BaseRecord < ApplicationRecord
    self.abstract_class = true
    self.ignored_columns = [] # Override ApplicationRecord settings

    connects_to database: {writing: :clickhouse, reading: :clickhouse}
  end
end
