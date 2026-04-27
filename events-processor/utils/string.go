package utils

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"strings"
)

type StringArray []string

func (a StringArray) Value() (driver.Value, error) {
	if a == nil {
		return nil, nil
	}
	return json.Marshal(a)
}

func (a *StringArray) Scan(value any) error {
	if value == nil {
		*a = []string{}
		return nil
	}

	switch v := value.(type) {
	case []byte:
		// Try JSON first (for JSONB column)
		var arr []string
		if err := json.Unmarshal(v, &arr); err == nil {
			*a = arr
			return nil
		}

		// Fallback to PostgreSQL array format: {value1, value2, value3}
		str := string(v)
		*a = parsePostgresArray(str)
		return nil
	case string:
		// PostgreSQL array as string
		*a = parsePostgresArray(v)
		return nil
	default:
		return fmt.Errorf("failed to unmarshal StringArray value: %v", value)
	}
}

func parsePostgresArray(s string) []string {
	s = strings.TrimSpace(s)

	// Handle empty array
	if s == "{}" || s == "" {
		return []string{}
	}

	// Remove curly braces
	s = strings.TrimPrefix(s, "{")
	s = strings.TrimSuffix(s, "}")

	// Split by comma and clean up quotes
	parts := strings.Split(s, ",")
	result := make([]string, 0, len(parts))

	for _, part := range parts {
		part = strings.TrimSpace(part)
		part = strings.Trim(part, "\"")
		if part != "" {
			result = append(result, part)
		}
	}

	return result
}

func (a StringArray) MarshalJSON() ([]byte, error) {
	return json.Marshal([]string(a))
}

func (a *StringArray) UnmarshalJSON(data []byte) error {
	var arr []string
	if err := json.Unmarshal(data, &arr); err != nil {
		return err
	}
	*a = StringArray(arr)
	return nil
}
