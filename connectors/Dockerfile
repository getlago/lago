# docker.redpanda.com mirrors Docker Hub, but the CI pull does not count as
# authenticated Docker Hub traffic. The anonymous Docker Hub rate limit
# applies, and GitHub-hosted runners share it across many workflows. Use
# docker.io directly to avoid the 429 errors.
# Docs: https://docs.redpanda.com/streaming/current/troubleshoot/errors-solutions/k-resolve-errors/
FROM docker.io/redpandadata/connect:4.83.0

COPY *.yml ./
