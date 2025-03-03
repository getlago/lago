package main

import (
	"github.com/getlago/lago/events-processor/processor"
)

func main() {
	// if os.Getenv("ENV") != "production" {
	// 	err := godotenv.Load()
	// 	if err != nil {
	// 		log.Fatal("Error loading .env file")
	// 	}
	// }

	// start processing events & loop forever
	processor.StartProcessingEvents()
}
