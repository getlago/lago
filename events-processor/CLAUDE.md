# Events Processor

## Build & Test

Run tests:
```
lago exec events-processor go test ./...
```

Direct `go build` / `go test` won't work locally due to CGO dependencies. Always use `lago exec` to run commands inside the service container.
