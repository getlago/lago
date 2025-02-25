package utils

type Result[T any] struct {
	value   T
	err     error
	details ErrorDetails
}

type ErrorDetails struct {
	Code    string
	Message string
}

func (r Result[T]) Success() bool {
	return r.err == nil
}

func (r Result[T]) Failure() bool {
	return r.err != nil
}

func (r Result[T]) ValueOrPanic() T {
	if r.Failure() {
		panic(r.err)
	}

	return r.value
}

func (r Result[T]) Value() T {
	return r.value
}

func (r Result[T]) Error() error {
	return r.err
}

func (r Result[T]) ErrorMsg() string {
	return r.err.Error()
}

func (r Result[T]) ErrorDetails() ErrorDetails {
	return r.details
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
		err: err,
	}
	return result
}

func FailedBoolResult(err error) Result[bool] {
	result := Result[bool]{
		err: err,
	}
	return result
}
