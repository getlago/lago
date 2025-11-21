package utils

import (
	"os"
	"strconv"
	"strings"
)

func GetEnvAsInt(key string, defaultValue int) (int, error) {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue, nil
	}

	intValue, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue, err
	}
	return intValue, nil
}

func ParseBrokersEnv(brokersStr string) []string {
	if brokersStr == "" {
		return []string{}
	}

	brokers := strings.Split(brokersStr, ",")
	for i, broker := range brokers {
		brokers[i] = strings.TrimSpace(broker)
	}

	return brokers
}

func GetEnvAsBool(key string, defaultValue bool) bool {
	value := os.Getenv(key)
	boolValue, err := strconv.ParseBool(value)
	if err != nil {
		return defaultValue
	}

	return boolValue
}
