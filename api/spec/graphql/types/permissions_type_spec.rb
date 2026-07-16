# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PermissionsType do
  it "matches the list of default permissions" do
    all_boolean = described_class.fields.values.all? do |f|
      f.type.to_type_signature == "Boolean!"
    end
    expect(all_boolean).to be_truthy

    gql_field_names = described_class.fields.keys.map(&:underscore)
    rails_field_names = Permission.permissions_hash.keys.map { |k| k.tr(":", "_") }
    expect(gql_field_names).to match_array(rails_field_names)
  end
end
