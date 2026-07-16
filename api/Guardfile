# frozen_string_literal: true

guard :rspec, cmd: "bundle exec rspec" do
  directories ["app", "db/seeds", "lib", "spec", "dev"]

  watch("spec/spec_helper.rb") { "spec" }
  watch("config/routes.rb") { "spec/routing" }
  watch("app/controllers/application_controller.rb") { "spec/requests" }
  watch("app/services/integrations/aggregator/invoices/payloads/base_payload.rb") do
    "spec/services/integrations/aggregator/invoices/payloads"
  end
  watch("app/services/integrations/aggregator/credit_notes/payloads/base_payload.rb") do
    "spec/services/integrations/aggregator/credit_notes/payloads"
  end
  watch("app/services/integrations/aggregator/contacts/payloads/base_payload.rb") do
    "spec/services/integrations/aggregator/contacts/payloads"
  end
  watch("app/services/integrations/aggregator/payments/payloads/base_payload.rb") do
    "spec/services/integrations/aggregator/payments/payloads"
  end

  watch(%r{^app/services/(customers/refresh_wallets_service|wallets/balance/refresh_ongoing_usage_service)\.rb$}) do
    [
      "spec/scenarios/wallets/balance_spec.rb",
      "spec/scenarios/wallets/customer_wallets_balance_refresh_spec.rb",
      "spec/scenarios/invoices/invoicing_with_prepaid_credits_spec.rb"
    ]
  end

  watch("app/services/integrations/aggregator/base_service.rb") { "spec/services/integrations/aggregator/" }
  watch("app/services/base_service.rb") { "spec/services/" }
  watch("app/jobs/application_job.rb") { "spec/jobs/" }
  watch("app/models/application_record.rb") { "spec/models/" }
  watch("app/mailers/application_mailer.rb") { "spec/mailers/" }
  watch("app/serializers/model_serializer.rb") { "spec/serializers/" }
  watch("app/graphql/lago_api_schema.rb") { "spec/graphql/" }
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^app/(.+)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(%r{^lib/tasks/(.+)\.rake$}) { |m| "spec/lib/tasks/#{m[1]}_rake_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$}) do |m|
    [
      "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb",
      "spec/requests/#{m[1]}_controller_spec.rb"
    ]
  end

  # Run schema check for any change in Graphql folder
  watch(%r{^app/graphql/(.+)\.rb$}) { |m| "spec/graphql/lago_api_schema_spec.rb" }
end
