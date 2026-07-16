# frozen_string_literal: true

ActiveSupport.on_load(:active_record) do
  require Rails.root.join("lib/migrations/extension_helper")

  ActiveRecord::Migration.include(Migrations::ExtensionHelper)
end
