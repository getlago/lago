package utils

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
)

var successResult = Result[string]{value: "Success", err: nil}
var failedResult = Result[string]{
	err:       fmt.Errorf("Failed result"),
	Capture:   true,
	Retryable: true,
	details: &ErrorDetails{
		Code:    "failed_result",
		Message: "More details",
	},
}

type booleanTest struct {
	arg      Result[string]
	expected bool
}

type stringTest struct {
	arg      Result[string]
	expected string
}

var successTests = []booleanTest{
	booleanTest{successResult, true},
	booleanTest{failedResult, false},
}

func TestSuccess(t *testing.T) {
	for _, test := range successTests {
		assert.Equal(t, test.arg.Success(), test.expected)
	}
}

var failureTests = []booleanTest{
	booleanTest{successResult, false},
	booleanTest{failedResult, true},
}

func TestFailure(t *testing.T) {
	for _, test := range failureTests {
		assert.Equal(t, test.arg.Failure(), test.expected)
	}
}

var valueTests = []stringTest{
	{successResult, "Success"},
	{failedResult, ""},
}

func TestValue(t *testing.T) {
	for _, test := range valueTests {
		assert.Equal(t, test.arg.Value(), test.expected)
	}
}

func TestValueOrPanic(t *testing.T) {
	assert.Panics(t, func() { failedResult.ValueOrPanic() })
	assert.Equal(t, successResult.ValueOrPanic(), "Success")
}

func TestError(t *testing.T) {
	assert.Nil(t, successResult.Error())
	assert.Error(t, failedResult.Error())
}

var errorMsgTests = []stringTest{
	{successResult, ""},
	{failedResult, "Failed result"},
}

func TestErrorMsg(t *testing.T) {
	for _, test := range errorMsgTests {
		assert.Equal(t, test.arg.ErrorMsg(), test.expected)
	}
}

func TestErrorDetails(t *testing.T) {
	assert.Nil(t, successResult.ErrorDetails())
	assert.NotNil(t, failedResult.ErrorDetails())
}

type resultTest struct {
	arg              Result[string]
	expectedSuccess  bool
	expectedFailure  bool
	expectedValue    any
	expectedErrorMsg string
}

var successResultTests = []resultTest{
	{
		SuccessResult("Success"),
		true,
		false,
		"Success",
		"",
	},
	{
		FailedResult[string](fmt.Errorf("Failed result")),
		false,
		true,
		"",
		"Failed result",
	},
}

func TestResults(t *testing.T) {
	for _, test := range successResultTests {
		assert.Equal(t, test.arg.Success(), test.expectedSuccess)
		assert.Equal(t, test.arg.Failure(), test.expectedFailure)
		assert.Equal(t, test.arg.Value(), test.expectedValue)
		assert.Equal(t, test.arg.ErrorMsg(), test.expectedErrorMsg)
	}
}

func TestNonCapturable(t *testing.T) {
	assert.True(t, failedResult.Capture)
	assert.True(t, failedResult.IsCapturable())
	assert.False(t, failedResult.NonCapturable().Capture)
	assert.False(t, failedResult.NonCapturable().IsCapturable())
}

func TestNonRetryable(t *testing.T) {
	assert.True(t, failedResult.Retryable)
	assert.True(t, failedResult.IsRetryable())
	assert.False(t, failedResult.NonRetryable().Retryable)
	assert.False(t, failedResult.NonRetryable().IsRetryable())
}
