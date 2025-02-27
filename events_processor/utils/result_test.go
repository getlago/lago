package utils

import (
	"fmt"
	"strconv"
	"testing"
)

var successResult = Result[string]{value: "Success", err: nil}
var failedResult = Result[string]{
	err: fmt.Errorf("Failed result"),
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
		if output := test.arg.Success(); output != test.expected {
			t.Errorf("Output %q not equal to expected %q", strconv.FormatBool(output), strconv.FormatBool(test.expected))
		}
	}
}

var failureTests = []booleanTest{
	booleanTest{successResult, false},
	booleanTest{failedResult, true},
}

func TestFailure(t *testing.T) {
	for _, test := range failureTests {
		if output := test.arg.Failure(); output != test.expected {
			t.Errorf("Output %q not equal to expected %q", strconv.FormatBool(output), strconv.FormatBool(test.expected))
		}
	}
}

var valueTests = []stringTest{
	{successResult, "Success"},
	{failedResult, ""},
}

func TestValue(t *testing.T) {
	for _, test := range valueTests {
		if output := test.arg.Value(); output != test.expected {
			t.Errorf("Output %q not equal to expected %q", output, test.expected)
		}
	}
}

func TestValueOrPanic(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Errorf("The code did not panic")
		}
	}()
	failedResult.ValueOrPanic()

	expected := "Success"
	if output := successResult.ValueOrPanic(); output != "Success" {
		t.Errorf("Output %q not equal to expected %q", output, expected)
	}
}

func TestError(t *testing.T) {
	if output := successResult.Error(); output != nil {
		t.Errorf("Output %q not equal to expected nil", output)
	}

	if output := failedResult.Error(); output.Error() != "Failed result" {
		t.Errorf("Output %q not equal to expected %q", output, "Failed result")
	}
}

var errorMsgTests = []stringTest{
	{successResult, ""},
	{failedResult, "Failed result"},
}

func TestErrorMsg(t *testing.T) {
	for _, test := range errorMsgTests {
		if output := test.arg.ErrorMsg(); output != test.expected {
			t.Errorf("Output %q not equal to expected %q", output, test.expected)
		}
	}
}

func TestErrorDetails(t *testing.T) {
	if output := successResult.ErrorDetails(); output != nil {
		t.Errorf("Output %q not equal to expected nil", output)
	}

	if output := failedResult.ErrorDetails(); output == nil {
		t.Errorf("Output %q not equal to expected not nil", output)
	}
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
		if output := test.arg.Success(); output != test.expectedSuccess {
			t.Errorf("Output %q not equal to expected %q", strconv.FormatBool(output), strconv.FormatBool(test.expectedSuccess))
		}

		if output := test.arg.Failure(); output != test.expectedFailure {
			t.Errorf("Output %q not equal to expected %q", strconv.FormatBool(output), strconv.FormatBool(test.expectedFailure))
		}

		if output := test.arg.Value(); output != test.expectedValue {
			t.Errorf("Output %q not equal to expected %q", output, test.expectedValue)
		}

		if output := test.arg.ErrorMsg(); output != test.expectedErrorMsg {
			t.Errorf("Output %q not equal to expected %q", output, test.expectedErrorMsg)
		}
	}
}
