package utils

import (
	"encoding/json"
	"reflect"
	"strings"
)

// UnmarshalNestedJSON handles JSON tags with dot notation (eg. "value.property")
// It supports extracting nested fields from parent objects during unmarshaling
func UnmarshalNestedJSON(data []byte, v interface{}) error {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}

	val := reflect.ValueOf(v).Elem()
	typ := val.Type()

	for i := 0; i < val.NumField(); i++ {
		field := val.Field(i)
		fieldType := typ.Field(i)
		jsonTag := fieldType.Tag.Get("json")

		if jsonTag == "" || jsonTag == "-" {
			continue
		}

		jsonTag = strings.Split(jsonTag, ",")[0]

		if strings.Contains(jsonTag, ".") {
			parts := strings.Split(jsonTag, ".")
			if len(parts) == 2 {
				parentJSON, exists := raw[parts[0]]
				if exists && string(parentJSON) != "null" {
					var parent map[string]json.RawMessage
					if err := json.Unmarshal(parentJSON, &parent); err == nil {
						if childJSON, ok := parent[parts[1]]; ok {
							json.Unmarshal(childJSON, field.Addr().Interface())
						}
					}
				}
			}
		} else {
			if rawValue, exists := raw[jsonTag]; exists {
				json.Unmarshal(rawValue, field.Addr().Interface())
			}
		}
	}

	return nil
}
