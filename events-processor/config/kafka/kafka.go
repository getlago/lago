package kafka

import (
	"log/slog"

	"github.com/getlago/lago/events-processor/config/tracing"
	"github.com/twmb/franz-go/pkg/kgo"
	"github.com/twmb/franz-go/pkg/sasl/scram"
	"github.com/twmb/franz-go/plugin/kslog"
)

const (
	Scram256 string = "SCRAM-SHA-256"
	Scram512 string = "SCRAM-SHA-512"
)

type ServerConfig struct {
	ScramAlgorithm string
	TLS            bool
	Servers        []string
	TracerProvider tracing.TracerProvider
	UserName       string
	Password       string
}

func NewKafkaClient(serverConfig ServerConfig, config []kgo.Opt) (*kgo.Client, error) {
	logger := slog.Default()
	logger = logger.With("component", "kafka")

	opts := []kgo.Opt{
		kgo.SeedBrokers(serverConfig.Servers...),
		kgo.WithLogger(kslog.New(logger)),
	}

	if len(config) > 0 {
		opts = append(opts, config...)
	}

	if serverConfig.TracerProvider != nil {
		hooks := serverConfig.TracerProvider.GetKafkaHooks()
		if len(hooks) > 0 {
			kotelOpt := kgo.WithHooks(hooks...)
			opts = append(opts, kotelOpt)
		}
	}

	if serverConfig.ScramAlgorithm != "" {
		var scramOpt kgo.Opt

		scramAuth := scram.Auth{
			User: serverConfig.UserName,
			Pass: serverConfig.Password,
		}

		switch serverConfig.ScramAlgorithm {
		case Scram256:
			scramOpt = kgo.SASL(scramAuth.AsSha256Mechanism())
		case Scram512:
			scramOpt = kgo.SASL(scramAuth.AsSha512Mechanism())
		}

		opts = append(opts, scramOpt)
	}

	if serverConfig.TLS {
		tlsOpt := kgo.DialTLS()
		opts = append(opts, tlsOpt)
	}

	client, err := kgo.NewClient(opts...)
	if err != nil {
		return nil, err
	}

	return client, nil
}
