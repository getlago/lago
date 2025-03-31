package utils

type Result[T any] struct {
	value     T
	err       error
	details   *ErrorDetails
	Retryable bool
	Capture   bool
}

type ErrorDetails struct {
	Code    string
	Message string
}

type AnyResult interface {
	Success() bool
	Failure() bool
	Error() error
	ErrorMsg() string
	ErrorCode() string
	ErrorMessage() string
	IsCapturable() bool
	IsRetryable() bool
}

func (r Result[T]) Success() bool {
	return r.err == nil
}

func (r Result[T]) Failure() bool {
	return r.err != nil
}

func (r Result[T]) Value() T {
	return r.value
}

func (r Result[T]) ValueOrPanic() T {
	if r.Failure() {
		panic(r.err)
	}

	return r.value
}

func (r Result[T]) Error() error {
	return r.err
}

func (r Result[T]) ErrorMsg() string {
	if r.Success() {
		return ""
	}

	return r.err.Error()
}

func (r Result[T]) AddErrorDetails(code string, message string) Result[T] {
	r.details = &ErrorDetails{
		Code:    code,
		Message: message,
	}
	return r
}

func (r Result[T]) NonRetryable() Result[T] {
	r.Retryable = false
	return r
}

func (r Result[T]) IsRetryable() bool {
	return r.Retryable
}

func (r Result[T]) NonCapturable() Result[T] {
	r.Capture = false
	return r
}

func (r Result[T]) IsCapturable() bool {
	return r.Capture
}

func (r Result[T]) ErrorDetails() *ErrorDetails {
	return r.details
}

func (r Result[T]) ErrorCode() string {
	if r.details == nil {
		return ""
	}

	return r.details.Code
}

func (r Result[T]) ErrorMessage() string {
	if r.details == nil {
		return ""
	}

	return r.details.Message
}

func SuccessResult[T any](value T) Result[T] {
	result := Result[T]{
		value: value,
		err:   nil,
	}
	return result
}

func FailedResult[T any](err error) Result[T] {
	result := Result[T]{
		err:       err,
		Capture:   true,
		Retryable: true,
	}
	return result
}

func FailedBoolResult(err error) Result[bool] {
	result := Result[bool]{
		err:       err,
		Capture:   true,
		Retryable: true,
	}
	return result
}
