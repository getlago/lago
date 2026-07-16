---
description: General Rails rules
globs: app/**/*.rb
alwaysApply: true
---

This projects runs in docker container, managed with docker-compose.
You must run `rspec` in the api container, use `lago exec api bundle exec rspec <args>`.
You must use the `rails` cli in the container too, for example: `lago exec api bin/rails db:migrate`.


# General style

- Never use `OpenStruct`
- avoid `if/unless` modifier right before the last line.
  USE
    ```
    if something
        this
    else
        that
    end
    ```
  AVOID
    ```
    return than unless something
    this
    ```

# Commit Messages

All commit messages must follow the Conventional Commits specification:

```
<type>[optional scope]: <description>

## Context

...

## Description

...
```

Where:
- `<type>` is one of: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert, misc
- `[optional scope]` is optional and describes the area of change (e.g., auth, billing, api)
- `<description>` is a short description of the change in imperative mood

**When generating or amending commit messages:**
- The first line must be 50 characters or less
- Use the imperative mood ("Add feature" not "Added feature")
- The body should
  - Explain the context and rationale for the change
  - Explain the "why" and "what" at a conceptual level, not the "how" at a code level
  - Be simple and direct using complete sentences without being verbose while keeping as much information as possible
- Check the whole diff at once using `PAGER=cat git diff ...` to see all changes together
- Generate the commit message based on the actual changes, not assumptions
- Do not check previous commits or commit history
- Only describe what was actually added or changed, not what already existed in the files

**When creating new commits:**
- Only analyze the current staged changes (`PAGER=cat git diff --staged`)

**When amending commits:**
- Always check the actual commit content first using `PAGER=cat git show HEAD` to see all changes and `PAGER=cat git diff --staged` to see staged changes
- Use `git commit --amend -m "message"` to update the commit message

# Services

- Creating, updating an deleting model must be done using a dedicated service, unless instructed otherwise.
For instance, to create an Alert model, you should create a `CreateAlertService` class.
- Before deleting a model, inspect it to determine if it's soft deletable (it includes `Discard::Model`). If soft deletable, use `model.discard`. Never hard delete a soft deletable model.


When creating a service class:
- the class always extend BaseService using `<`
- the class name should always end with `Service`
- the class should always be placed in `app/services/**/*.rb`
- Service class takes named arguments via the constructor and arguments are stored in instance variables.
- Each instance variable should have a private attr_reader declared
- Service class have one and only one public method named `call` and it never accepts arguments
- Service `call` method should always return `result`
- Service class must define a custom Result class following these rules:
  - By default, `Result = BaseResult`
  - If the service must return values, define them using `BaseResult[]`. Example of result returning a customer and a subcription: `Result = BaseResult[:customer, :subscription]`



# Jobs
To call the class service class asynchronously, create job:
- jobs should have the exact same fully qualified class name except it ends with `Job` instead of `Service`.
- the perform method of the job typically calls the matching service and forwards all it's arguements
- the service is called using the class method `call!`
- avoid using named parameters for jobs

Example of job calling a service:

```ruby
# frozen_string_literal: true

module SomeModuleName
  class MyGeneratedJob < ApplicationJob
    queue_as "default"

    def perform(organization, subscription)
      SomeModuleName::MyGeneratedService.call!(organization:, subscription:)
    end
  end
end

```

# Controllers

- Under `V1` namespace the resource retrieved should always be scoped to the current_organization. Typically, to retrieve Alerts, use `current_organization.alerts.where(...)`
- In controller `create` method, return regular 200 status, avoid `status: :created`
- When testing controller, access the response via `json` method, which parsed json and symbolized keys.


# Models

- New models must directly belong to an organization. Store the `organization_id` in the table, don't use `through:`

Soft deletion
- not all models are soft deletable
- soft deletable models must `include Discard::Model`
- the soft deletion column is called `deleted_at`
- soft deletable models must use `default_scope -> { kept }`
- soft deletable models should be deletable
- You cannot rely on `dependent: :destroy` if the model is soft deleted, you must call `discard_all!` on relationship manually

## Enums

- Define enum constants as arrays before using them in enum declarations
- For PostgreSQL enums, define constants as hashes with string values, not arrays. Use the format: `ENUM_NAME = { value1: "value1", value2: "value2" }.freeze`.
- New model enums should always use `validate: true`

Example:

  ```ruby
  FEE_TYPES = %i[charge add_on subscription credit commitment].freeze
  enum :fee_type, FEE_TYPES

  ON_TERMINATION_CREDIT_NOTES = { credit: "credit", omit: "omit" }.freeze
  enum :on_termination_credit_note, ON_TERMINATION_CREDIT_NOTES
  ```

# Webhooks

To create a webhook:
- A webhook name is typically `resource.action`, for example: `customer.updated` or `alert.triggered`. Use other webhooks as example to follow.
- Create a service in `app/services/webhooks/`, typically named `Webhooks::ResourceActionService` like `Webhooks::CustomerUpdatedService`
- A service must define at least the following methods:
    - `current_organization` - how to get the organization from the model
    - `object_serializer` which typically calls a serializer class
    - `webhook_type` always the name like `resource.action`
    - `object_type` which is the object serialized. Reuse this method in the serializer `root_name` param
- Add the mapping `name` => Service class to the `SendWebhookJob::WEBHOOK_SERVICES` hash
- Write a test for the webhook class

# Migrations

- Make sure to specify the latest available `ActiveRecord::Migration` version. For example, if the latest version is `8.0`, use `ActiveRecord::Migration[8.0]`.
- Prefer `add_column` over `change_table` when adding single columns
- Use `safety_assured` wrapper when required for complex operations
- Never use hardcoded or fake timestamps in migration filenames. Migration timestamps should be generated using `date +"%Y%m%d%H%M%S"` command to ensure proper chronological ordering.
- For enums, use `create_enum` to define the PostgreSQL enum type before adding the column
  - Enum type names should be descriptive and include the table/model context (e.g., `subscription_on_termination_credit_note`)

# Backward Compatibility

- New optional parameters must not break existing functionality

# Service

## Validation

- Use descriptive error messages that explain why validation failed
- Always validate enum values in a service validation class to prevent invalid API input

# Query object

- When using ransack with search_params, make sure the attributes are defined in the model class method `self.ransackable_attributes(_auth_object = nil)`

# Testing

- Do not test `#initialize` method.
- In controller specs, use `get_with_token` and similar method, don't try to mock the token manually
- to test a "resource not found error" from an `Api::V1` controller, use the custom match `be_not_found_error` like this:
  `expect(response).to be_not_found_error("alert")`
- Prefer `expect(...).to have_received()` instead of `expect(...).to receive()`
- never use `aggregate_failure` in new test. Do not edit existing tests to remove it.
- After making changes to the tests, always run the tests to ensure they pass.
- When doing array comparison in tests, use `eq` or `match_array` instead of multiple `include`/`not_to include` assertions when the expected array is small enough to be readable
- Use single-line `let` statements when they fit on one line without breaking Rubocop rules
- Use `let!` only for objects that need to be created before the test runs; if not referencing the object in tests, consider creating them directly in a `before` block instead of using `let`
- Run as minimum number of tests as possible. Narrow down run tests for specific describe or file.

## Models

- When testing models, test all enums and group them all in a `describe "enums"` block with a single `it` block (not multiple `it` blocks)
  - When testing PostgreSQL enums, use the `.backed_by_column_of_type(:enum)` matcher:
    ```ruby
    expect(subject).to define_enum_for(:on_termination_credit_note)
      .backed_by_column_of_type(:enum)
      .validating
      .with_values(credit: "credit", omit: "omit")
    ```
- When testing models, test ALL associations (belongs_to, has_one, has_many, etc.) and group them all in a `describe "associations"` block with a single `it` block (not multiple `it` blocks)
  - Include ALL association parameters and options (class_name, foreign_key, through, dependent, autosave, optional, etc.)
  - Clickhouse associations should have their own `describe "Clickhouse associations"` block with `clickhouse: true` metadata after the associations block
- When testing models, test all scopes and group them all in a `describe "Scopes"` block with individual `describe ".scope_name"` blocks for each scope
- When testing models, test all validations and group them all in a `describe "validations"` block with a single `it` block
  - For complex custom validations, use a nested `describe "attribute_name validation"` block instead of using the method name
- Test sections should appear in this order: enums, associations, Clickhouse associations, scopes, validations

## Factories

- Some factories have been renamed for clarity.
  - To create Entitlement::Feature model, use `:feature`
  - To create Entitlement::Privilege model, use `:privilege`
  - To create Entitlement::Entitlement model, use `:entitlement`
