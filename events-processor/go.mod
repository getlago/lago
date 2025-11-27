module github.com/getlago/lago/events-processor

go 1.24.0

require (
	github.com/DATA-DOG/go-sqlmock v1.5.2
	github.com/getlago/lago-expression/expression-go v0.1.4
	github.com/getsentry/sentry-go v0.38.0
	github.com/jackc/pgx/v5 v5.7.6
	github.com/orandin/slog-gorm v1.4.0
	github.com/redis/go-redis/extra/redisotel/v9 v9.17.0
	github.com/redis/go-redis/v9 v9.17.0
	github.com/stretchr/testify v1.11.1
	github.com/twmb/franz-go v1.20.5
	github.com/twmb/franz-go/plugin/kotel v1.6.0
	github.com/twmb/franz-go/plugin/kslog v1.0.0
	go.opentelemetry.io/otel v1.38.0
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.38.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace v1.38.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.38.0
	go.opentelemetry.io/otel/sdk v1.38.0
	go.opentelemetry.io/otel/sdk/metric v1.38.0
	go.opentelemetry.io/otel/trace v1.38.0
	golang.org/x/sync v0.18.0
	google.golang.org/grpc v1.77.0
	gopkg.in/DataDog/dd-trace-go.v1 v1.74.8
	gorm.io/driver/postgres v1.6.0
	gorm.io/gorm v1.31.1
)

require (
	cloud.google.com/go v0.112.1 // indirect
	cloud.google.com/go/compute/metadata v0.9.0 // indirect
	cloud.google.com/go/iam v1.1.7 // indirect
	cloud.google.com/go/pubsub v1.37.0 // indirect
	github.com/99designs/gqlgen v0.17.72 // indirect
	github.com/DataDog/datadog-agent/comp/core/tagger/origindetection v0.72.2 // indirect
	github.com/DataDog/datadog-agent/pkg/obfuscate v0.72.2 // indirect
	github.com/DataDog/datadog-agent/pkg/opentelemetry-mapping-go/otlp/attributes v0.72.2 // indirect
	github.com/DataDog/datadog-agent/pkg/proto v0.72.2 // indirect
	github.com/DataDog/datadog-agent/pkg/remoteconfig/state v0.74.0-devel // indirect
	github.com/DataDog/datadog-agent/pkg/trace v0.72.2 // indirect
	github.com/DataDog/datadog-agent/pkg/util/log v0.72.2 // indirect
	github.com/DataDog/datadog-agent/pkg/util/scrubber v0.72.2 // indirect
	github.com/DataDog/datadog-agent/pkg/version v0.72.2 // indirect
	github.com/DataDog/datadog-go/v5 v5.8.1 // indirect
	github.com/DataDog/dd-trace-go/contrib/99designs/gqlgen/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/IBM/sarama/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/Shopify/sarama/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/aws/aws-sdk-go-v2/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/aws/aws-sdk-go/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/cloud.google.com/go/pubsub.v1/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/confluentinc/confluent-kafka-go/kafka.v2/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/confluentinc/confluent-kafka-go/kafka/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/database/sql/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/elastic/go-elasticsearch.v6/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/gin-gonic/gin/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/go-chi/chi.v5/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/go-chi/chi/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/go-redis/redis.v7/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/go-redis/redis.v8/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/go-redis/redis/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/go.mongodb.org/mongo-driver/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/gocql/gocql/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/gofiber/fiber.v2/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/gomodule/redigo/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/google.golang.org/grpc/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/gorilla/mux/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/gorm.io/gorm.v1/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/graph-gophers/graphql-go/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/graphql-go/graphql/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/hashicorp/vault/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/jackc/pgx.v5/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/julienschmidt/httprouter/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/k8s.io/client-go/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/labstack/echo.v4/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/log/slog/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/net/http/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/redis/go-redis.v9/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/redis/rueidis/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/segmentio/kafka-go/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/sirupsen/logrus/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/twitchtv/twirp/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/contrib/valkey-io/valkey-go/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/instrumentation/testutils/grpc/v2 v2.3.0 // indirect
	github.com/DataDog/dd-trace-go/v2 v2.4.0 // indirect
	github.com/DataDog/go-libddwaf/v4 v4.7.0 // indirect
	github.com/DataDog/go-runtime-metrics-internal v0.0.4-0.20250721125240-fdf1ef85b633 // indirect
	github.com/DataDog/go-sqllexer v0.1.10 // indirect
	github.com/DataDog/go-tuf v1.1.1-0.5.2 // indirect
	github.com/DataDog/gostackparse v0.7.0 // indirect
	github.com/DataDog/opentelemetry-mapping-go/pkg/otlp/attributes v0.33.0 // indirect
	github.com/DataDog/sketches-go v1.4.7 // indirect
	github.com/IBM/sarama v1.40.0 // indirect
	github.com/Masterminds/semver/v3 v3.4.0 // indirect
	github.com/Microsoft/go-winio v0.6.2 // indirect
	github.com/Shopify/sarama v1.38.1 // indirect
	github.com/andybalholm/brotli v1.1.0 // indirect
	github.com/aws/aws-sdk-go v1.44.327 // indirect
	github.com/aws/aws-sdk-go-v2 v1.26.1 // indirect
	github.com/aws/aws-sdk-go-v2/aws/protocol/eventstream v1.6.2 // indirect
	github.com/aws/aws-sdk-go-v2/internal/configsources v1.3.5 // indirect
	github.com/aws/aws-sdk-go-v2/internal/endpoints/v2 v2.6.5 // indirect
	github.com/aws/aws-sdk-go-v2/internal/v4a v1.3.5 // indirect
	github.com/aws/aws-sdk-go-v2/service/dynamodb v1.31.1 // indirect
	github.com/aws/aws-sdk-go-v2/service/eventbridge v1.30.4 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/accept-encoding v1.11.2 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/checksum v1.3.7 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/endpoint-discovery v1.9.6 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/presigned-url v1.11.7 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/s3shared v1.17.5 // indirect
	github.com/aws/aws-sdk-go-v2/service/kinesis v1.27.4 // indirect
	github.com/aws/aws-sdk-go-v2/service/s3 v1.53.1 // indirect
	github.com/aws/aws-sdk-go-v2/service/sfn v1.26.4 // indirect
	github.com/aws/aws-sdk-go-v2/service/sns v1.29.4 // indirect
	github.com/aws/aws-sdk-go-v2/service/sqs v1.31.4 // indirect
	github.com/aws/smithy-go v1.20.2 // indirect
	github.com/bytedance/sonic v1.12.0 // indirect
	github.com/bytedance/sonic/loader v0.2.0 // indirect
	github.com/cenkalti/backoff/v3 v3.2.2 // indirect
	github.com/cenkalti/backoff/v5 v5.0.3 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/cihub/seelog v0.0.0-20170130134532-f561c5e57575 // indirect
	github.com/cloudwego/base64x v0.1.4 // indirect
	github.com/cloudwego/iasm v0.2.0 // indirect
	github.com/confluentinc/confluent-kafka-go v1.9.2 // indirect
	github.com/confluentinc/confluent-kafka-go/v2 v2.4.0 // indirect
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/dustin/go-humanize v1.0.1 // indirect
	github.com/eapache/go-resiliency v1.4.0 // indirect
	github.com/eapache/go-xerial-snappy v0.0.0-20230731223053-c322873962e3 // indirect
	github.com/eapache/queue v1.1.0 // indirect
	github.com/ebitengine/purego v0.9.1 // indirect
	github.com/felixge/httpsnoop v1.0.4 // indirect
	github.com/gabriel-vasile/mimetype v1.4.3 // indirect
	github.com/gin-contrib/sse v0.1.0 // indirect
	github.com/gin-gonic/gin v1.10.1 // indirect
	github.com/go-chi/chi v1.5.4 // indirect
	github.com/go-chi/chi/v5 v5.2.2 // indirect
	github.com/go-jose/go-jose/v3 v3.0.4 // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/go-ole/go-ole v1.3.0 // indirect
	github.com/go-playground/locales v0.14.1 // indirect
	github.com/go-playground/universal-translator v0.18.1 // indirect
	github.com/go-playground/validator/v10 v10.20.0 // indirect
	github.com/go-redis/redis v6.15.9+incompatible // indirect
	github.com/go-redis/redis/v7 v7.4.1 // indirect
	github.com/go-redis/redis/v8 v8.11.5 // indirect
	github.com/go-viper/mapstructure/v2 v2.4.0 // indirect
	github.com/goccy/go-json v0.10.2 // indirect
	github.com/gocql/gocql v1.6.0 // indirect
	github.com/gofiber/fiber/v2 v2.52.9 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang/groupcache v0.0.0-20210331224755-41bb18bfe9da // indirect
	github.com/golang/protobuf v1.5.4 // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/gomodule/redigo v1.8.9 // indirect
	github.com/google/pprof v0.0.0-20250403155104-27863c87afa6 // indirect
	github.com/google/s2a-go v0.1.7 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/googleapis/enterprise-certificate-proxy v0.3.2 // indirect
	github.com/googleapis/gax-go/v2 v2.12.2 // indirect
	github.com/gorilla/mux v1.8.1 // indirect
	github.com/graph-gophers/graphql-go v1.5.0 // indirect
	github.com/graphql-go/graphql v0.8.1 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.27.3 // indirect
	github.com/hailocab/go-hostpool v0.0.0-20160125115350-e80d13ce29ed // indirect
	github.com/hashicorp/errwrap v1.1.0 // indirect
	github.com/hashicorp/go-cleanhttp v0.5.2 // indirect
	github.com/hashicorp/go-multierror v1.1.1 // indirect
	github.com/hashicorp/go-retryablehttp v0.7.7 // indirect
	github.com/hashicorp/go-rootcerts v1.0.2 // indirect
	github.com/hashicorp/go-secure-stdlib/parseutil v0.2.0 // indirect
	github.com/hashicorp/go-secure-stdlib/strutil v0.1.2 // indirect
	github.com/hashicorp/go-sockaddr v1.0.7 // indirect
	github.com/hashicorp/go-uuid v1.0.3 // indirect
	github.com/hashicorp/go-version v1.7.0 // indirect
	github.com/hashicorp/hcl v1.0.1-vault-5 // indirect
	github.com/hashicorp/vault/api v1.9.2 // indirect
	github.com/hashicorp/vault/sdk v0.9.2 // indirect
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	github.com/jcmturner/aescts/v2 v2.0.0 // indirect
	github.com/jcmturner/dnsutils/v2 v2.0.0 // indirect
	github.com/jcmturner/gofork v1.7.6 // indirect
	github.com/jcmturner/gokrb5/v8 v8.4.4 // indirect
	github.com/jcmturner/rpc/v2 v2.0.3 // indirect
	github.com/jinzhu/gorm v1.9.16 // indirect
	github.com/jinzhu/inflection v1.0.0 // indirect
	github.com/jinzhu/now v1.1.5 // indirect
	github.com/jmespath/go-jmespath v0.4.0 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/julienschmidt/httprouter v1.3.0 // indirect
	github.com/klauspost/compress v1.18.1 // indirect
	github.com/klauspost/cpuid/v2 v2.3.0 // indirect
	github.com/labstack/echo/v4 v4.11.1 // indirect
	github.com/labstack/gommon v0.4.2 // indirect
	github.com/leodido/go-urn v1.4.0 // indirect
	github.com/lufia/plan9stats v0.0.0-20251013123823-9fd1530e3ec3 // indirect
	github.com/mattn/go-colorable v0.1.14 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/mattn/go-runewidth v0.0.16 // indirect
	github.com/minio/simdjson-go v0.4.5 // indirect
	github.com/mitchellh/go-homedir v1.1.0 // indirect
	github.com/mitchellh/mapstructure v1.5.1-0.20231216201459-8508981c8b6c // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.3-0.20250322232337-35a7c28c31ee // indirect
	github.com/outcaste-io/ristretto v0.2.3 // indirect
	github.com/pelletier/go-toml/v2 v2.2.2 // indirect
	github.com/philhofer/fwd v1.2.0 // indirect
	github.com/pierrec/lz4/v4 v4.1.22 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/planetscale/vtprotobuf v0.6.1-0.20240319094008-0393e58bdf10 // indirect
	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
	github.com/power-devops/perfstat v0.0.0-20240221224432-82ca36839d55 // indirect
	github.com/puzpuzpuz/xsync/v3 v3.5.1 // indirect
	github.com/rcrowley/go-metrics v0.0.0-20201227073835-cf1acfcdf475 // indirect
	github.com/redis/go-redis/extra/rediscmd/v9 v9.17.0 // indirect
	github.com/redis/rueidis v1.0.56 // indirect
	github.com/richardartoul/molecule v1.0.1-0.20240531184615-7ca0df43c0b3 // indirect
	github.com/rivo/uniseg v0.4.7 // indirect
	github.com/ryanuber/go-glob v1.0.0 // indirect
	github.com/secure-systems-lab/go-securesystemslib v0.9.1 // indirect
	github.com/segmentio/kafka-go v0.4.42 // indirect
	github.com/shirou/gopsutil/v4 v4.25.10 // indirect
	github.com/sirupsen/logrus v1.9.3 // indirect
	github.com/sosodev/duration v1.3.1 // indirect
	github.com/spaolacci/murmur3 v1.1.0 // indirect
	github.com/theckman/httpforwarded v0.4.0 // indirect
	github.com/tinylib/msgp v1.5.0 // indirect
	github.com/tklauser/go-sysconf v0.3.16 // indirect
	github.com/tklauser/numcpus v0.11.0 // indirect
	github.com/twitchtv/twirp v8.1.3+incompatible // indirect
	github.com/twitchyliquid64/golang-asm v0.15.1 // indirect
	github.com/twmb/franz-go/pkg/kmsg v1.12.0 // indirect
	github.com/ugorji/go/codec v1.2.12 // indirect
	github.com/valkey-io/valkey-go v1.0.56 // indirect
	github.com/valyala/bytebufferpool v1.0.0 // indirect
	github.com/valyala/fasthttp v1.51.0 // indirect
	github.com/valyala/fasttemplate v1.2.2 // indirect
	github.com/valyala/tcplisten v1.0.0 // indirect
	github.com/vektah/gqlparser/v2 v2.5.25 // indirect
	github.com/yusufpapurcu/wmi v1.2.4 // indirect
	go.mongodb.org/mongo-driver v1.12.1 // indirect
	go.opencensus.io v0.24.0 // indirect
	go.opentelemetry.io/auto/sdk v1.2.1 // indirect
	go.opentelemetry.io/collector/component v1.46.0 // indirect
	go.opentelemetry.io/collector/featuregate v1.46.0 // indirect
	go.opentelemetry.io/collector/internal/telemetry v0.140.0 // indirect
	go.opentelemetry.io/collector/pdata v1.46.0 // indirect
	go.opentelemetry.io/collector/semconv v0.128.0 // indirect
	go.opentelemetry.io/contrib/bridges/otelzap v0.13.0 // indirect
	go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc v0.49.0 // indirect
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.49.0 // indirect
	go.opentelemetry.io/otel/log v0.14.0 // indirect
	go.opentelemetry.io/otel/metric v1.38.0 // indirect
	go.opentelemetry.io/proto/otlp v1.9.0 // indirect
	go.uber.org/atomic v1.11.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	go.uber.org/zap v1.27.1 // indirect
	go.yaml.in/yaml/v3 v3.0.4 // indirect
	golang.org/x/arch v0.8.0 // indirect
	golang.org/x/crypto v0.45.0 // indirect
	golang.org/x/exp v0.0.0-20251113190631-e25ba8c21ef6 // indirect
	golang.org/x/mod v0.30.0 // indirect
	golang.org/x/net v0.47.0 // indirect
	golang.org/x/oauth2 v0.32.0 // indirect
	golang.org/x/sys v0.38.0 // indirect
	golang.org/x/text v0.31.0 // indirect
	golang.org/x/time v0.14.0 // indirect
	golang.org/x/xerrors v0.0.0-20240903120638-7835f813f4da // indirect
	google.golang.org/api v0.169.0 // indirect
	google.golang.org/genproto v0.0.0-20240325203815-454cdb8f5daa // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20251111163417-95abcf5c77ba // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20251111163417-95abcf5c77ba // indirect
	google.golang.org/protobuf v1.36.10 // indirect
	gopkg.in/inf.v0 v0.9.1 // indirect
	gopkg.in/ini.v1 v1.67.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	k8s.io/apimachinery v0.32.3 // indirect
	k8s.io/client-go v0.31.4 // indirect
	k8s.io/klog/v2 v2.130.1 // indirect
	k8s.io/utils v0.0.0-20241210054802-24370beab758 // indirect
)
