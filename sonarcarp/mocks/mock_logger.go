package mocks

import "github.com/op/go-logging"

type LogBackendMock struct {
	DebugCalls, InfoCalls, WarningCalls, ErrorCalls int
}

func (l *LogBackendMock) Log(level logging.Level, _ int, _ *logging.Record) error {
	switch level {
	case logging.DEBUG:
		l.DebugCalls++
	case logging.INFO:
		l.InfoCalls++
	case logging.WARNING:
		l.WarningCalls++
	case logging.ERROR:
		l.ErrorCalls++
	default:
		panic("unexpected log level call")
	}

	return nil
}
func (l *LogBackendMock) GetLevel(string) logging.Level  { return logging.DEBUG }
func (l *LogBackendMock) SetLevel(logging.Level, string) {}
func (l *LogBackendMock) IsEnabledFor(logging.Level, string) bool {
	return true
}

func CreateLoggingMock(logger *logging.Logger) (*LogBackendMock, func()) {
	loggerCopy := *logger

	resetLogger := func() {
		logger = &loggerCopy
	}

	lbm := &LogBackendMock{}
	logger.SetBackend(lbm)

	return lbm, resetLogger
}
