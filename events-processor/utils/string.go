package utils

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"strings"
	"unicode"
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

	if !strings.HasPrefix(s, "{") || !strings.HasSuffix(s, "}") {
		return []string{strings.Trim(s, "\"")}
	}

	s = strings.TrimSuffix(strings.TrimPrefix(s, "{"), "}")
	result := make([]string, 0)
	var current strings.Builder
	inQuotes := false
	escaped := false
	quoted := false
	tokenStarted := false

	appendValue := func() {
		value := current.String()
		if !quoted {
			value = strings.TrimSpace(value)
		}
		if quoted || value != "" {
			result = append(result, value)
		}
		current.Reset()
		quoted = false
		tokenStarted = false
	}

	for _, char := range s {
		switch {
		case escaped:
			current.WriteRune(char)
			escaped = false
			tokenStarted = true
		case char == '\\' && inQuotes:
			escaped = true
		case char == '"':
			inQuotes = !inQuotes
			quoted = true
			tokenStarted = true
		case char == ',' && !inQuotes:
			appendValue()
		case !inQuotes && quoted && unicode.IsSpace(char):
			continue
		case !inQuotes && !tokenStarted && unicode.IsSpace(char):
			continue
		default:
			current.WriteRune(char)
			tokenStarted = true
		}
	}

	appendValue()

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
