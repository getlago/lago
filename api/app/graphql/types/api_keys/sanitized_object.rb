# frozen_string_literal: true

module Types
  module ApiKeys
    class SanitizedObject < Object
      graphql_name "SanitizedApiKey"

      def value
        "••••••••" + object.value.last(3)
      end
    end
  end
end
