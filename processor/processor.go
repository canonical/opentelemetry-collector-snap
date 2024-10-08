// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package processor // import "go.opentelemetry.io/collector/processor"

import (
	"context"
	"fmt"

	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/pipeline"
)

// Traces is a processor that can consume traces.
type Traces interface {
	component.Component
	consumer.Traces
}

// Metrics is a processor that can consume metrics.
type Metrics interface {
	component.Component
	consumer.Metrics
}

// Logs is a processor that can consume logs.
type Logs interface {
	component.Component
	consumer.Logs
}

// Settings is passed to Create* functions in Factory.
type Settings struct {
	// ID returns the ID of the component that will be created.
	ID component.ID

	component.TelemetrySettings

	// BuildInfo can be used by components for informational purposes
	BuildInfo component.BuildInfo
}

// Factory is Factory interface for processors.
//
// This interface cannot be directly implemented. Implementations must
// use the NewFactory to implement it.
type Factory interface {
	component.Factory

	// CreateTracesProcessor creates a TracesProcessor based on this config.
	// If the processor type does not support traces,
	// this function returns the error [pipeline.ErrSignalNotSupported].
	// Implementers can assume `nextConsumer` is never nil.
	CreateTracesProcessor(ctx context.Context, set Settings, cfg component.Config, nextConsumer consumer.Traces) (Traces, error)

	// TracesProcessorStability gets the stability level of the TracesProcessor.
	TracesProcessorStability() component.StabilityLevel

	// CreateMetricsProcessor creates a MetricsProcessor based on this config.
	// If the processor type does not support metrics,
	// this function returns the error [pipeline.ErrSignalNotSupported].
	// Implementers can assume `nextConsumer` is never nil.
	CreateMetricsProcessor(ctx context.Context, set Settings, cfg component.Config, nextConsumer consumer.Metrics) (Metrics, error)

	// MetricsProcessorStability gets the stability level of the MetricsProcessor.
	MetricsProcessorStability() component.StabilityLevel

	// CreateLogsProcessor creates a LogsProcessor based on the config.
	// If the processor type does not support logs,
	// this function returns the error [pipeline.ErrSignalNotSupported].
	// Implementers can assume `nextConsumer` is never nil.
	CreateLogsProcessor(ctx context.Context, set Settings, cfg component.Config, nextConsumer consumer.Logs) (Logs, error)

	// LogsProcessorStability gets the stability level of the LogsProcessor.
	LogsProcessorStability() component.StabilityLevel

	unexportedFactoryFunc()
}

// FactoryOption apply changes to Options.
type FactoryOption interface {
	// applyProcessorFactoryOption applies the option.
	applyProcessorFactoryOption(o *factory)
}

var _ FactoryOption = (*factoryOptionFunc)(nil)

// factoryOptionFunc is a FactoryOption created through a function.
type factoryOptionFunc func(*factory)

func (f factoryOptionFunc) applyProcessorFactoryOption(o *factory) {
	f(o)
}

type factory struct {
	cfgType component.Type
	component.CreateDefaultConfigFunc
	CreateTracesFunc
	tracesStabilityLevel component.StabilityLevel
	CreateMetricsFunc
	metricsStabilityLevel component.StabilityLevel
	CreateLogsFunc
	logsStabilityLevel component.StabilityLevel
}

func (f *factory) Type() component.Type {
	return f.cfgType
}

func (f *factory) unexportedFactoryFunc() {}

func (f factory) TracesProcessorStability() component.StabilityLevel {
	return f.tracesStabilityLevel
}

func (f factory) MetricsProcessorStability() component.StabilityLevel {
	return f.metricsStabilityLevel
}

func (f factory) LogsProcessorStability() component.StabilityLevel {
	return f.logsStabilityLevel
}

// CreateTracesFunc is the equivalent of Factory.CreateTraces().
type CreateTracesFunc func(context.Context, Settings, component.Config, consumer.Traces) (Traces, error)

// CreateTracesProcessor implements Factory.CreateTracesProcessor().
func (f CreateTracesFunc) CreateTracesProcessor(
	ctx context.Context,
	set Settings,
	cfg component.Config,
	nextConsumer consumer.Traces) (Traces, error) {
	if f == nil {
		return nil, pipeline.ErrSignalNotSupported
	}
	return f(ctx, set, cfg, nextConsumer)
}

// CreateMetricsFunc is the equivalent of Factory.CreateMetrics().
type CreateMetricsFunc func(context.Context, Settings, component.Config, consumer.Metrics) (Metrics, error)

// CreateMetricsProcessor implements Factory.CreateMetricsProcessor().
func (f CreateMetricsFunc) CreateMetricsProcessor(
	ctx context.Context,
	set Settings,
	cfg component.Config,
	nextConsumer consumer.Metrics,
) (Metrics, error) {
	if f == nil {
		return nil, pipeline.ErrSignalNotSupported
	}
	return f(ctx, set, cfg, nextConsumer)
}

// CreateLogsFunc is the equivalent of Factory.CreateLogs().
type CreateLogsFunc func(context.Context, Settings, component.Config, consumer.Logs) (Logs, error)

// CreateLogsProcessor implements Factory.CreateLogsProcessor().
func (f CreateLogsFunc) CreateLogsProcessor(
	ctx context.Context,
	set Settings,
	cfg component.Config,
	nextConsumer consumer.Logs,
) (Logs, error) {
	if f == nil {
		return nil, pipeline.ErrSignalNotSupported
	}
	return f(ctx, set, cfg, nextConsumer)
}

// WithTraces overrides the default "error not supported" implementation for CreateTraces and the default "undefined" stability level.
func WithTraces(createTraces CreateTracesFunc, sl component.StabilityLevel) FactoryOption {
	return factoryOptionFunc(func(o *factory) {
		o.tracesStabilityLevel = sl
		o.CreateTracesFunc = createTraces
	})
}

// WithMetrics overrides the default "error not supported" implementation for CreateMetrics and the default "undefined" stability level.
func WithMetrics(createMetrics CreateMetricsFunc, sl component.StabilityLevel) FactoryOption {
	return factoryOptionFunc(func(o *factory) {
		o.metricsStabilityLevel = sl
		o.CreateMetricsFunc = createMetrics
	})
}

// WithLogs overrides the default "error not supported" implementation for CreateLogs and the default "undefined" stability level.
func WithLogs(createLogs CreateLogsFunc, sl component.StabilityLevel) FactoryOption {
	return factoryOptionFunc(func(o *factory) {
		o.logsStabilityLevel = sl
		o.CreateLogsFunc = createLogs
	})
}

// NewFactory returns a Factory.
func NewFactory(cfgType component.Type, createDefaultConfig component.CreateDefaultConfigFunc, options ...FactoryOption) Factory {
	f := &factory{
		cfgType:                 cfgType,
		CreateDefaultConfigFunc: createDefaultConfig,
	}
	for _, opt := range options {
		opt.applyProcessorFactoryOption(f)
	}
	return f
}

// MakeFactoryMap takes a list of factories and returns a map with Factory type as keys.
// It returns a non-nil error when there are factories with duplicate type.
func MakeFactoryMap(factories ...Factory) (map[component.Type]Factory, error) {
	fMap := map[component.Type]Factory{}
	for _, f := range factories {
		if _, ok := fMap[f.Type()]; ok {
			return fMap, fmt.Errorf("duplicate processor factory %q", f.Type())
		}
		fMap[f.Type()] = f
	}
	return fMap, nil
}
