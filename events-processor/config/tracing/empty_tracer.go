package tracing

import (
	"context"
)

// EmptySpan implements the Span interface.
type EmptySpan struct {
	ctx context.Context
}

func (s EmptySpan) SetAttribute(key string, value any)      {}
func (s EmptySpan) SetAttributes(attributes map[string]any) {}
func (s EmptySpan) SetError(err error)                      {}
func (s EmptySpan) End()                                    {}
func (s EmptySpan) GetContext() context.Context             { return s.ctx }

// EmptyTracer implements the Tracer interface
type EmptyTracer struct{}

func NewEmptyTracer() *EmptyTracer {
	return &EmptyTracer{}
}

func (t *EmptyTracer) StartSpan(ctx context.Context, operationName string, opts ...SpanOption) Span {
	return EmptySpan{ctx}
}

// EmptyTracerProvider implements the TracerProvider interface
type EmptyTracerProvider struct{}

func (p *EmptyTracerProvider) Stop() {}
