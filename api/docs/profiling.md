# Profiling

## Overview

In development environment, we can use [Vernier](https://github.com/jhawthorn/vernier) to profile the execution of Sidekiq jobs.

## Configuration

To enable profiling, set the `SIDEKIQ_PROFILING_ENABLED` environment variable to `true` in your `.env` file.

```bash
# lago/.env.development
SIDEKIQ_PROFILING_ENABLED=true
```

Then restart the worker process:

```bash
lago down api-worker
lago up -d api-worker
```

## Profiling jobs

Once the worker process is restarted, all jobs with be profiled. The profiling results will be saved in the `tmp/profiling` directory with the following format: `tmp/profiling/{job_class}/{timestamp}-{job_id}.json`.

## Profiling results

The profiling results are in JSON format and can be analyzed using the [`profile-viewer`](https://rubygems.org/gems/profile-viewer) gem.

First install the gem:

```bash
gem install profile-viewer
```

Then open the profiling result in your browser:

```bash
profile-viewer tmp/profiling/WalletTransactions::CreateJob/2025-11-19T15:25:18+00:00-9c5e70f60126f7248c8e224b.json
```

## Recommendations

When profiling, it is recommended to disable class reloading in the `config/environment/development.rb` file to avoid unnecessary slowdowns and noises in the profiling results:

```ruby
# lago-api/config/environment/development.rb
config.enable_reloading = false
```

Then restart the worker process.
