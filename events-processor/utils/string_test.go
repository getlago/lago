package utils

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestStringArray_Value(t *testing.T) {
	tests := []struct {
		name      string
		array     StringArray
		expected  string
		expectNil bool
	}{
		{
			name:     "empty array",
			array:    StringArray{},
			expected: "[]",
		},
		{
			name:      "nil array",
			array:     nil,
			expectNil: true,
		},
		{
			name:     "single element",
			array:    StringArray{"value1"},
			expected: `["value1"]`,
		},
		{
			name:     "multiple elements",
			array:    StringArray{"value1", "value2", "value3"},
			expected: `["value1","value2","value3"]`,
		},
		{
			name:     "with special characters",
			array:    StringArray{"value_1", "value-2"},
			expected: `["value_1","value-2"]`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			value, err := tt.array.Value()

			require.NoError(t, err)

			if tt.expectNil {
				assert.Nil(t, value)
				return
			}

			assert.IsType(t, []byte{}, value)
			assert.JSONEq(t, tt.expected, string(value.([]byte)))
		})
	}
}

func TestStringArray_Scan(t *testing.T) {
	tests := []struct {
		name     string
		input    interface{}
		expected StringArray
		wantErr  bool
	}{
		{
			name:     "nil value",
			input:    nil,
			expected: StringArray{},
			wantErr:  false,
		},
		{
			name:     "empty array",
			input:    []byte("[]"),
			expected: StringArray{},
			wantErr:  false,
		},
		{
			name:     "single element",
			input:    []byte(`["value1"]`),
			expected: StringArray{"value1"},
			wantErr:  false,
		},
		{
			name:     "multiple elements",
			input:    []byte(`["value1","value2","value3"]`),
			expected: StringArray{"value1", "value2", "value3"},
			wantErr:  false,
		},
		{
			name:     "with special character",
			input:    []byte(`["value_1","value-2"]`),
			expected: StringArray{"value_1", "value-2"},
			wantErr:  false,
		},
		{
			name:     "string input treated as single element",
			input:    "plain string",
			expected: StringArray{"plain string"},
			wantErr:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var array StringArray
			err := array.Scan(tt.input)

			if tt.wantErr {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)
			assert.Equal(t, tt.expected, array)
		})
	}
}

func TestStringArray_MarshalJSON(t *testing.T) {
	tests := []struct {
		name     string
		array    StringArray
		expected string
	}{
		{
			name:     "nil array",
			array:    nil,
			expected: "null",
		},
		{
			name:     "empty array",
			array:    StringArray{},
			expected: "[]",
		},
		{
			name:     "single element",
			array:    StringArray{"value1"},
			expected: `["value1"]`,
		},
		{
			name:     "multiple elements",
			array:    StringArray{"value1", "value2", "value3"},
			expected: `["value1","value2","value3"]`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := tt.array.MarshalJSON()
			require.NoError(t, err)
			assert.JSONEq(t, tt.expected, string(result))
		})
	}
}

func TestStringArray_UnmarshalJSON(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected StringArray
		wantErr  bool
	}{
		{
			name:     "empty array",
			input:    "[]",
			expected: StringArray{},
			wantErr:  false,
		},
		{
			name:     "single element",
			input:    `["value1"]`,
			expected: StringArray{"value1"},
			wantErr:  false,
		},
		{
			name:     "multiple elements",
			input:    `["value1","value2","value3"]`,
			expected: StringArray{"value1", "value2", "value3"},
			wantErr:  false,
		},
		{
			name:     "invalid JSON",
			input:    `not valid json"`,
			expected: StringArray(nil),
			wantErr:  true,
		},
		{
			name:     "non-array JSON",
			input:    `{"key":"value"}`,
			expected: StringArray(nil),
			wantErr:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var array StringArray
			err := array.UnmarshalJSON([]byte(tt.input))

			if tt.wantErr {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err)
			assert.Equal(t, tt.expected, array)
		})
	}
}

func TestStringArray_RoundTrip(t *testing.T) {
	tests := []struct {
		name  string
		array StringArray
	}{
		{
			name:  "empty array",
			array: StringArray{},
		},
		{
			name:  "single element",
			array: StringArray{"value1"},
		},
		{
			name:  "multiple elements",
			array: StringArray{"value1", "value2", "value3"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			value, err := tt.array.Value()
			require.NoError(t, err)

			var scanned StringArray
			err = scanned.Scan(value)
			require.NoError(t, err)
			assert.Equal(t, tt.array, scanned)

			jsonBytes, err := tt.array.MarshalJSON()
			require.NoError(t, err)

			var unmarshaled StringArray
			err = unmarshaled.UnmarshalJSON(jsonBytes)
			require.NoError(t, err)
			assert.Equal(t, tt.array, unmarshaled)
		})
	}
}

func TestStringArray_InStruct(t *testing.T) {
	type TestStruct struct {
		Values StringArray `json:"values"`
	}

	t.Run("marshal struct with StringArray", func(t *testing.T) {
		s := TestStruct{
			Values: StringArray{"value1", "value2"},
		}

		jsonBytes, err := json.Marshal(s)
		require.NoError(t, err)
		assert.JSONEq(t, `{"values":["value1","value2"]}`, string(jsonBytes))
	})

	t.Run("unmarshal struct with StringArray", func(t *testing.T) {
		jsonStr := `{"values":["value1","value2"]}`
		var s TestStruct

		err := json.Unmarshal([]byte(jsonStr), &s)
		require.NoError(t, err)
		assert.Equal(t, StringArray{"value1", "value2"}, s.Values)
	})
}
