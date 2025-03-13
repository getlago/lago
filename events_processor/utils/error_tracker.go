package utils

import "github.com/getsentry/sentry-go"

func CaptureErrorResult(errResult AnyResult) {
	sentry.WithScope(func(scope *sentry.Scope) {
		scope.SetExtra("error_code", errResult.ErrorCode())
		scope.SetExtra("error_message", errResult.ErrorMessage())
		sentry.CaptureException(errResult.Error())
	})
}

func CaptureError(err error) {
	sentry.CaptureException(err)
}
