package config

import (
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func NewConnection() {
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
}

func main() {

}
