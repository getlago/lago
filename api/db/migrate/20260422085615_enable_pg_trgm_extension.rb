# frozen_string_literal: true

class EnablePgTrgmExtension < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pg_trgm"
    enable_extension "btree_gin"
  end
end
