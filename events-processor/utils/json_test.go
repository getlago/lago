package utils

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type TestStruct struct {
	ID           string      `json:"id"`
	Name         string      `json:"name"`
	NestedField  string      `json:"properties.nested_field"`
	AnotherField int         `json:"metadata.count"`
	NormalField  bool        `json:"active"`
	IgnoredField string      `json:"-"`
	ArrayField   StringArray `json:"properties.tags"`
}

func TestUnmarshalNestedJSON_SimpleFields(t *testing.T) {
	data := []byte(`{
		"id": "123",
		"name": "test",
		"active": true
	}`)

	var result TestStruct
	err := UnmarshalNestedJSON(data, &result)

	require.NoError(t, err)
	assert.Equal(t, "123", result.ID)
	assert.Equal(t, "test", result.Name)
	assert.Equal(t, true, result.NormalField)
}

func TestUnmarshalNestedJSON_NestedField(t *testing.T) {
	data := []byte(`{
		"id": "123",
		"properties": {
			"nested_field": "nested_value",
			"tags": ["tag1", "tag2"]
		},
		"metadata": {
			"count": 42
		}
	}`)

	var result TestStruct
	err := UnmarshalNestedJSON(data, &result)

	require.NoError(t, err)
	assert.Equal(t, "123", result.ID)
	assert.Equal(t, "nested_value", result.NestedField)
	assert.Equal(t, 42, result.AnotherField)
	assert.Equal(t, StringArray{"tag1", "tag2"}, result.ArrayField)
}

func TestUnmarshalNestedJSON_MissingNestedField(t *testing.T) {
	data := []byte(`{
		"id": "123",
		"properties": {
			"other_field": "value"
		}
	}`)

	var result TestStruct
	err := UnmarshalNestedJSON(data, &result)

	require.NoError(t, err)
	assert.Equal(t, "", result.NestedField)
}

func TestUnmarshalNestedJSON_NullParent(t *testing.T) {
	data := []byte(`{
		"id": "null-test",
		"properties": null
	}`)

	var result TestStruct
	err := UnmarshalNestedJSON(data, &result)

	require.NoError(t, err)
	assert.Equal(t, "", result.NestedField)
}

func TestUnmarshalNestedJSON_MissingParent(t *testing.T) {
	data := []byte(`{
		"id": "missing-parent",
		"name": "test"
	}`)

	var result TestStruct
	err := UnmarshalNestedJSON(data, &result)

	require.NoError(t, err)
	assert.Equal(t, "", result.NestedField)
}

func TestUnmarshalNestedJSON_InvalidJSON(t *testing.T) {
	data := []byte(`{invalid json}`)

	var result TestStruct
	err := UnmarshalNestedJSON(data, &result)

	assert.Error(t, err)
}

func TestUnmarshalNestedJSON_EmptyJSON(t *testing.T) {
	data := []byte(`{}`)

	var result TestStruct
	err := UnmarshalNestedJSON(data, &result)

	require.NoError(t, err)
}
