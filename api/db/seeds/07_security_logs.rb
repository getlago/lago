# frozen_string_literal: true

return unless License.premium?
return if ENV["LAGO_CLICKHOUSE_ENABLED"].blank?

topic = Utils::SecurityLog.topic
return if topic.blank?

existing = Karafka::Admin.cluster_info.topics.map { |t| t[:topic_name] }
unless existing.include?(topic)
  Karafka::Admin.create_topic(topic, 1, 1)
end

organization = Organization.find_by!(name: "Hooli")
user = organization.memberships.first!.user
device_info = {
  user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  ip_address: "192.168.1.42",
  browser: "Chrome 131.0.0.0",
  os: "Mac",
  device_type: "desktop"
}

Utils::SecurityLog.produce(
  organization:,
  log_type: "user",
  log_event: "user.signed_up",
  user:,
  device_info:,
  skip_organization_check: true
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "user",
  log_event: "user.new_device_logged_in",
  user:,
  device_info:
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "user",
  log_event: "user.deleted",
  user:,
  device_info:,
  resources: {email: "dinesh@hooli.com"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "user",
  log_event: "user.invited",
  user:,
  device_info:,
  resources: {invitee_email: "invited@example.com"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "user",
  log_event: "user.role_edited",
  user:,
  device_info:,
  resources: {email: "dinesh@hooli.com", roles: {deleted: %w[admin], added: %w[finance]}}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "user",
  log_event: "user.password_reset_requested",
  user:,
  device_info:,
  resources: {email: "gavin@hooli.com"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "user",
  log_event: "user.password_edited",
  user:,
  device_info:,
  resources: {email: "gavin@hooli.com"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "role",
  log_event: "role.created",
  user:,
  device_info:,
  resources: {role_code: "accountant", permissions: %w[customers:view invoices:view invoices:create]}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "role",
  log_event: "role.updated",
  user:,
  device_info:,
  resources: {role_code: "accountant", permissions: {added: %w[invoices:view invoices:create]}}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "role",
  log_event: "role.deleted",
  user:,
  device_info:,
  resources: {role_code: "hr_manager"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "api_key",
  log_event: "api_key.created",
  user:,
  device_info:,
  resources: {name: "Hooli Key", value_ending: "7890", permissions: ApiKey.default_permissions}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "api_key",
  log_event: "api_key.updated",
  user:,
  device_info:,
  resources: {name: "Hooli Key", value_ending: "7890", permissions: {add_on: {deleted: %w[write]}}}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "api_key",
  log_event: "api_key.deleted",
  user:,
  device_info:,
  resources: {name: "Expired Key", value_ending: "4321"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "api_key",
  log_event: "api_key.rotated",
  user:,
  device_info:,
  resources: {name: "Hooli Key", value_ending: {deleted: "7890", added: "5678"}}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "webhook_endpoint",
  log_event: "webhook_endpoint.created",
  user:,
  device_info:,
  resources: {webhook_url: "https://webhook.example.com/#{organization.id}"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "webhook_endpoint",
  log_event: "webhook_endpoint.updated",
  user:,
  device_info:,
  resources: {webhook_url: {deleted: "https://webhook.example.com/old", added: "https://webhook.example.com/#{organization.id}"}}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "webhook_endpoint",
  log_event: "webhook_endpoint.deleted",
  user:,
  device_info:,
  resources: {webhook_url: "https://webhook.example.com/#{organization.id}"}
)

api_key = organization.api_keys.first
Utils::SecurityLog.produce(
  organization:,
  log_type: "webhook_endpoint",
  log_event: "webhook_endpoint.deleted",
  api_key:,
  resources: {webhook_url: "https://webhook.example.com/api-deleted"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "export",
  log_event: "export.created",
  user:,
  device_info:,
  resources: {export_type: "invoices"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "integration",
  log_event: "integration.created",
  user:,
  device_info:,
  resources: {integration_name: "Netsuite Production", integration_type: "netsuite"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "integration",
  log_event: "integration.updated",
  user:,
  device_info:,
  resources: {integration_name: "Netsuite Production", integration_type: "netsuite", name: {deleted: "Netsuite Old", added: "Netsuite Production"}}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "integration",
  log_event: "integration.deleted",
  user:,
  device_info:,
  resources: {integration_name: "Okta Production", integration_type: "okta"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "billing_entity",
  log_event: "billing_entity.created",
  user:,
  device_info:,
  resources: {billing_entity_name: "Hooli", billing_entity_code: "hooli"}
)

Utils::SecurityLog.produce(
  organization:,
  log_type: "billing_entity",
  log_event: "billing_entity.updated",
  user:,
  device_info:,
  resources: {billing_entity_name: "Hooli", billing_entity_code: "hooli", name: {deleted: "Hooli Old", added: "Hooli"}}
)
