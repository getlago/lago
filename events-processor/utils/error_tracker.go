package utils

import "github.com/getsentry/sentry-go"

func CaptureErrorResult(errResult AnyResult) {
	CaptureErrorResultWithExtra(errResult, "", nil)
}

func CaptureErrorResultWithExtra(errResult AnyResult, extraKey string, extraValue any) {
	sentry.WithScope(func(scope *sentry.Scope) {
		scope.SetExtra("error_code", errResult.ErrorCode())
		scope.SetExtra("error_message", errResult.ErrorMessage())

		if extraKey != "" {
			scope.SetExtra(extraKey, extraValue)
		}

		sentry.CaptureException(errResult.Error())
	})
}

func CaptureError(err error) {
	sentry.CaptureException(err)
}
