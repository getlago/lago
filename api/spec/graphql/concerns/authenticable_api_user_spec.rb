# frozen_string_literal: true

require "rails_helper"

module AuthenticableApiUserSpec
  class ThingType < Types::BaseObject
    field :name, String, null: false
    field :count, Integer
  end

  class RenameThingMutation < Mutations::BaseMutation
    include AuthenticableApiUser

    graphql_name "RenameThing"
    argument :new_name, String, required: true
    type ThingType

    def resolve(**args)
      {name: args[:new_name], count: 1}
    end
  end

  class ThingsMutationType < Types::BaseObject
    field :renameThing, mutation: RenameThingMutation
  end

  class TestApiSchema < LagoApiSchema
    mutation(ThingsMutationType)
  end
end

RSpec.describe AuthenticableApiUser do
  let(:mutation) do
    <<-GQL
      mutation($input: RenameThingInput!) {
        renameThing(input: $input) {
          name
        }
      }
    GQL
  end

  context "with a current user" do
    it "renames the thing" do
      membership = create(:membership)

      result = AuthenticableApiUserSpec::TestApiSchema.execute(
        mutation,
        variables: {input: {newName: "new name"}},
        context: {current_user: membership.user}
      )

      expect(result["data"]["renameThing"]["name"]).to eq "new name"
    end
  end

  context "without a current user" do
    it "returns an error" do
      result = AuthenticableApiUserSpec::TestApiSchema.execute(
        mutation,
        variables: {input: {newName: "new name"}},
        context: {current_user: nil}
      )

      partial_error = {
        "message" => "unauthorized",
        "extensions" => {"status" => :unauthorized, "code" => "unauthorized"}
      }

      expect(result["errors"]).to include hash_including(partial_error)
    end
  end
end
