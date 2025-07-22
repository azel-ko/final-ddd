package logger

import (
	"fmt"
	"github.com/fatih/color"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"os"
	"time"
)

var log *zap.Logger

// 颜色常量
var (
	infoColor    = color.New(color.FgGreen).SprintFunc()
	warnColor    = color.New(color.FgYellow).SprintFunc()
	errorColor   = color.New(color.FgRed).SprintFunc()
	defaultColor = color.New(color.FgWhite).SprintFunc()
)

// CustomTimeEncoder 自定义时间编码器
func CustomTimeEncoder(t time.Time, enc zapcore.PrimitiveArrayEncoder) {
	enc.AppendString(t.Format("2006-01-02 15:04:05.000"))
}

//// CustomLevelEncoder 自定义级别颜色编码器
//func CustomLevelEncoder(level zapcore.Level, enc zapcore.PrimitiveArrayEncoder) {
//	var levelStr string
//	switch level {
//	case zapcore.InfoLevel:
//		levelStr = infoColor(fmt.Sprintf("%-6s", level.String()))
//	case zapcore.WarnLevel:
//		levelStr = warnColor(fmt.Sprintf("%-6s", level.String()))
//	case zapcore.ErrorLevel:
//		levelStr = errorColor(fmt.Sprintf("%-6s", level.String()))
//	default:
//		levelStr = defaultColor(fmt.Sprintf("%-6s", level.String()))
//	}
//	enc.AppendString(levelStr)
//}

// CustomLevelEncoder 自定义级别编码器
func CustomLevelEncoder(level zapcore.Level, enc zapcore.PrimitiveArrayEncoder) {
	// 直接添加未着色的级别字符串
	enc.AppendString(fmt.Sprintf("%-6s", level.String()))
}

func Init(le string) {
	// 创建基础配置
	encoderConfig := zapcore.EncoderConfig{
		TimeKey:        "timestamp",
		LevelKey:       "level",
		NameKey:        "logger",
		CallerKey:      "caller",
		FunctionKey:    zapcore.OmitKey,
		MessageKey:     "msg",
		LineEnding:     zapcore.DefaultLineEnding,
		EncodeLevel:    CustomLevelEncoder,
		EncodeTime:     CustomTimeEncoder,
		EncodeDuration: zapcore.SecondsDurationEncoder,
		EncodeCaller:   zapcore.ShortCallerEncoder,
	}

	// 创建输出
	// 控制台输出
	consoleEncoder := zapcore.NewConsoleEncoder(encoderConfig)
	consoleOutput := zapcore.AddSync(os.Stdout)

	// 文件输出
	fileEncoder := zapcore.NewJSONEncoder(encoderConfig)
	logFile, _ := os.OpenFile("logs/app.log", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	fileOutput := zapcore.AddSync(logFile)

	// 设置日志级别
	level := getLogLevel(le)
	core := zapcore.NewTee(
		zapcore.NewCore(consoleEncoder, consoleOutput, level),
		zapcore.NewCore(fileEncoder, fileOutput, level),
	)

	// 创建Logger
	log = zap.New(core, zap.AddCaller(), zap.AddCallerSkip(1))
	//suger = log.Sugar()
	Info("Starting application...")
}

func getLogLevel(level string) zapcore.Level {
	switch level {
	case "debug":
		return zapcore.DebugLevel
	case "info":
		return zapcore.InfoLevel
	case "warn":
		return zapcore.WarnLevel
	case "error":
		return zapcore.ErrorLevel
	default:
		return zapcore.InfoLevel
	}
}

// 日志方法
func Debug(msg string, fields ...zapcore.Field) {
	log.Debug(msg, fields...)
}

func Info(msg string, fields ...zapcore.Field) {
	log.Info(msg, fields...)
}

func Warn(msg string, fields ...zapcore.Field) {
	log.Warn(msg, fields...)
}

func Error(msg string, fields ...zapcore.Field) {
	log.Error(msg, fields...)
}

func Fatal(msg string, fields ...zapcore.Field) {
	log.Fatal(msg, fields...)
}
