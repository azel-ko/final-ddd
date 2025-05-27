package version

import (
	"fmt"
	"runtime"
)

// 通过 -ldflags 在构建时注入的变量
var (
	Version    = "dev"
	BuildTime  = "unknown"
	CommitHash = "unknown"
)

// Info 返回应用程序的版本信息
type Info struct {
	Version    string `json:"version"`
	BuildTime  string `json:"build_time"`
	CommitHash string `json:"commit_hash"`
	GoVersion  string `json:"go_version"`
	OS         string `json:"os"`
	Arch       string `json:"arch"`
}

// Get 返回当前应用程序的版本信息
func Get() Info {
	return Info{
		Version:    Version,
		BuildTime:  BuildTime,
		CommitHash: CommitHash,
		GoVersion:  runtime.Version(),
		OS:         runtime.GOOS,
		Arch:       runtime.GOARCH,
	}
}

// String 返回格式化的版本信息字符串
func String() string {
	info := Get()
	return fmt.Sprintf(
		"Version: %s\nBuild Time: %s\nCommit Hash: %s\nGo Version: %s\nOS/Arch: %s/%s",
		info.Version,
		info.BuildTime,
		info.CommitHash,
		info.GoVersion,
		info.OS,
		info.Arch,
	)
} 