package pipeline

import "github.com/getlago/lago/events-processor/utils"

// FailedResult wraps a failure with the error details the dead letter queue
// reports, keeping whether it is retryable and capturable.
func FailedResult[T any](r utils.AnyResult, code string, message string) utils.Result[T] {
	result := utils.FailedResult[T](r.Error()).AddErrorDetails(code, message)
	result.Retryable = r.IsRetryable()
	result.Capture = r.IsCapturable()
	return result
}
