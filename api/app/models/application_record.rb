# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Avoid raising ActiveRecord::PreparedStatementCacheExpired
  # from transactions when a migration is adding a new column
  self.ignored_columns = [:__fake_column__]
end
