package models

import (
	"fmt"
	"log/slog"
	"time"

	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type StreamQueryConfig struct {
	TableName      string
	SelectFields   []string
	WhereCondition string
	WhereArgs      []interface{}
	LogInterval    int
}

func StreamRows[T any](db *gorm.DB, config StreamQueryConfig, callback func(T) error) (int, error) {
	startTime := time.Now()

	logger := slog.Default()
	logger.Debug("Starting streaming query", slog.String("table", config.TableName))

	query := db.Table(config.TableName).Select(config.SelectFields)

	if config.WhereCondition != "" {
		query = query.Where(config.WhereCondition, config.WhereArgs...)
	}

	rows, err := query.Rows()
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	count := 0
	logInterval := config.LogInterval
	if logInterval == 0 {
		logInterval = 50000
	}

	for rows.Next() {
		var item T

		err := db.ScanRows(rows, &item)

		if err != nil {
			logger.Error(
				"error while scanning row",
				slog.String("table", config.TableName),
			)
			return count, err
		}

		if err := callback(item); err != nil {
			return count, err
		}

		count++

		if count%logInterval == 0 {
			elapsed := time.Since(startTime)

			logger.Debug(
				"streaming process",
				slog.String("table", config.TableName),
				slog.Int("rows_loaded", count),
				slog.Int64("elapsed_ms", elapsed.Milliseconds()),
				slog.Float64("rows_per_sec", float64(count)/elapsed.Seconds()),
			)
		}
	}

	if err := rows.Err(); err != nil {
		logger.Error(
			"error during rows iteration",
			slog.String("table", config.TableName),
		)
		return count, err
	}

	duration := time.Since(startTime)
	logger.Info(
		"completed streaming query",
		slog.String("table", config.TableName),
		slog.Int("count", count),
		slog.Int64("duration_ms", duration.Milliseconds()),
		slog.Float64("rows_per_sec", float64(count)/duration.Seconds()),
	)

	return count, nil
}

func GetAllWithStreaming[T any](db *gorm.DB, config StreamQueryConfig) utils.Result[[]T] {
	items := make([]T, 0, 100000)
	logger := slog.Default()

	_, err := StreamRows(db, config, func(item T) error {
		fmt.Printf("ITEM: %v\n", item)
		items = append(items, item)
		return nil
	})

	if err != nil {
		return utils.FailedResult[[]T](err)
	}

	logger.Info(
		"completed streaming query",
		slog.String("table", config.TableName),
	)

	return utils.SuccessResult(items)
}
