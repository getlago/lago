# frozen_string_literal: true

require "cop_helper"

RSpec.describe Cops::NoDropColumnOrTableCop, :config do
  describe "remove_column" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        remove_column :users, :email
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Dropping columns or tables is disabled due to the risks involved. See docs/dropping_columns_and_tables.md for more information.
      RUBY
    end

    it "registers an offense inside change_table block" do
      expect_offense(<<~RUBY)
        change_table :users do |t|
          t.remove_column :email
          ^^^^^^^^^^^^^^^^^^^^^^ Dropping columns or tables is disabled due to the risks involved. See docs/dropping_columns_and_tables.md for more information.
        end
      RUBY
    end
  end

  describe "remove_columns" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        remove_columns :users, :email, :name
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Dropping columns or tables is disabled due to the risks involved. See docs/dropping_columns_and_tables.md for more information.
      RUBY
    end
  end

  describe "drop_table" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        drop_table :users
        ^^^^^^^^^^^^^^^^^ Dropping columns or tables is disabled due to the risks involved. See docs/dropping_columns_and_tables.md for more information.
      RUBY
    end

    it "registers an offense with a block" do
      expect_offense(<<~RUBY)
        drop_table :users do |t|
        ^^^^^^^^^^^^^^^^^ Dropping columns or tables is disabled due to the risks involved. See docs/dropping_columns_and_tables.md for more information.
          t.string :email
        end
      RUBY
    end
  end

  describe "allowed methods" do
    it "does not register an offense for add_column" do
      expect_no_offenses(<<~RUBY)
        add_column :users, :email, :string
      RUBY
    end

    it "does not register an offense for create_table" do
      expect_no_offenses(<<~RUBY)
        create_table :users do |t|
          t.string :email
        end
      RUBY
    end

    it "does not register an offense for rename_column" do
      expect_no_offenses(<<~RUBY)
        rename_column :users, :email, :email_address
      RUBY
    end
  end
end
