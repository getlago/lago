package pipeline

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
	"golang.org/x/sync/errgroup"

	"github.com/getlago/lago/events-processor/config/tracing"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

// ProcessRecords processes a batch concurrently and returns the records to commit.
func ProcessRecords(
	ctx context.Context,
	records []*kgo.Record,
	spanName string,
	process func(context.Context, *models.Event) utils.AnyResult,
	deadLetter func(context.Context, models.Event, utils.AnyResult),
) []*kgo.Record {
	span := tracing.StartSpan(ctx, spanName)
	defer span.End()

	span.SetAttribute("records.length", len(records))

	g := errgroup.Group{}

	var mu sync.Mutex
	processedRecords := make([]*kgo.Record, 0)

	for _, record := range records {
		g.Go(func() error {
			func(record *kgo.Record) {
				sp := tracing.StartSpan(ctx, "PostProcess.ProcessOneEvent")
				defer sp.End()

				event := models.Event{}
				err := json.Unmarshal(record.Value, &event)
				if err != nil {
					slog.Error("Error unmarshalling message", slog.String("error", err.Error()))
					utils.CaptureError(err)

					mu.Lock()
					// If we fail to unmarshal the record, we should commit it as it will failed forever
					processedRecords = append(processedRecords, record)
					mu.Unlock()
					return
				}

				result := process(ctx, &event)
				if result.Failure() {
					slog.Error(
						result.ErrorMessage(),
						slog.String("error_code", result.ErrorCode()),
						slog.String("error", result.ErrorMsg()),
					)

					if result.IsCapturable() {
						utils.CaptureErrorResultWithExtra(result, "event", event)
					}

					if result.IsRetryable() && time.Since(event.IngestedAt.Time()) < 12*time.Hour {
						// For retryable errors, we should avoid commiting the record,
						// It will be consumed again and reprocessed
						// Events older than 12 hours should also be pushed dead letter queue
						return
					}

					// Push failed records to the dead letter queue
					deadLetter(ctx, event, result)
				}

				// Track processed records
				mu.Lock()
				processedRecords = append(processedRecords, record)
				mu.Unlock()
			}(record)

			return nil
		})
	}

	g.Wait()
	return processedRecords
}
