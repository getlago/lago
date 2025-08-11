package event_processors

import (
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func failedResult(r utils.AnyResult, code string, message string) utils.Result[*models.EnrichedEvent] {
	result := utils.FailedResult[*models.EnrichedEvent](r.Error()).AddErrorDetails(code, message)
	result.Retryable = r.IsRetryable()
	result.Capture = r.IsCapturable()
	return result
}

func failedMultiEventsResult(r utils.AnyResult, code string, message string) utils.Result[[]*models.EnrichedEvent] {
	result := utils.FailedResult[[]*models.EnrichedEvent](r.Error()).AddErrorDetails(code, message)
	result.Retryable = r.IsRetryable()
	result.Capture = r.IsCapturable()
	return result
}

func toMultiEventsResult(r utils.Result[*models.EnrichedEvent]) utils.Result[[]*models.EnrichedEvent] {
	return failedMultiEventsResult(r, r.ErrorCode(), r.ErrorMessage())
}
