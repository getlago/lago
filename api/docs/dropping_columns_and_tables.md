# Dropping Columns and Tables

Dropping columns or tables in migrations is **not recommended** and will be flagged by our custom RuboCop cop `Lago/NoDropColumnOrTable`.

## Why is dropping columns or tables problematic ?

Dropping columns or tables can lead to significant issues in a production environment and requires careful planning and coordination, especially in an open source context.

### 1. Two-step migration complexity

Safely removing a column requires a two-step process:

1. **First deploy**: Remove all code references to the column and add the column to `ignored_columns` in the model
2. **Second deploy**: Actually drop the column from the database

This two-step process is error-prone because:

- If code still references the column when it's dropped, the application will crash during deployment
- Rolling back becomes complex if issues arise between the two deploys
- It requires careful coordination between code changes and database changes

### 2. Open source release constraints

As an open source application, this two-step migration has additional implications:

- **Two separate OSS releases** are required (one to ignore the column, one to drop it)
- **Migration documentation** must be provided to users explaining the upgrade path:
  - Users running self-hosted instances need clear instructions on when and how to upgrade
  - Skipping versions becomes risky if column drops are not properly documented

## How to properly drop a column or table

If you absolutely need to drop a column or table, follow this process:

### Step 1: Deprecate the column or table (Release N)

1. Remove all code references to the column or table
2. For columns drop, add the column to `ignored_columns` in the model:

    ```ruby
    class User < ApplicationRecord
      # TODO: Remove after version X.Y.Z
      self.ignored_columns += %w[deprecated_column_name]
    end
    ```

3. Create a specific release including this change
4. Document this in the release notes

### Step 2: Drop the column or table (Release N+1 or later)

1. Create a dedicated migration commit that:

   - **Contains ONLY the column or table drop** - no other code changes
   - **May contain multiple column or table drops** if they were all properly deprecated in previous releases
   - **Documents the version** that removed the references to the column/table and eventually introduced the `ignored_columns` entry
   - Add the migration to the exclusion list in the `.rubocop.yml`

    Example commit message:

    ```md
    chore(db): drop deprecated columns

    ## Context

    These columns were deprecated in previous version and have been in
    `ignored_columns` since then.

    ## Description

    Drop the following columns:
    - `users.deprecated_column_name` (ignored since vX.Y.Z)
    - `subscriptions.old_status` (ignored since vX.Y.Z)
    ```

2. Create a specific release including this change
3. Add a release note documenting the column or table drops and the upgrade path from the previous release. You can find such an example here: <https://www.getlago.com/docs/guide/migration/migration-to-v1.32.0#what-should-self-hosted-users-do>.
