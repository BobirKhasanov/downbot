package main

import (
	"fmt"
	"net/http"
	"os"

	_ "net/http/pprof" // profiler

	"github.com/govdbot/govd/internal/bot"
	"github.com/govdbot/govd/internal/config"
	"github.com/govdbot/govd/internal/database"
	"github.com/govdbot/govd/internal/localization"
	"github.com/govdbot/govd/internal/logger"
	"github.com/govdbot/govd/internal/util"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	logger.Init()
	defer logger.L.Sync()

	config.Load()
	logger.SetLevel(config.Env.LogLevel)

	if !util.CheckFFmpeg() {
		logger.L.Fatal("ffmpeg binary not found in PATH")
	}

	// --- RENDER HEALTH CHECK START ---
	// This ensures Render sees the service as "Live"
	go func() {
		port := os.Getenv("PORT")
		if port == "" {
			port = "10000" // Fallback for local dev
		}
		logger.L.Infof("Starting health check server on port %s", port)
		// Use a dedicated ServeMux so we don't conflict with metrics/profiler
		mux := http.NewServeMux()
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			fmt.Fprint(w, "OK")
		})
		if err := http.ListenAndServe(":"+port, mux); err != nil {
			logger.L.Errorf("Health check server failed: %v", err)
		}
	}()
	// --- RENDER HEALTH CHECK END ---

	if len(config.Env.Admins) > 0 {
		logger.L.Infof("admins: %v", config.Env.Admins)
	}

	if len(config.Env.Whitelist) > 0 {
		config.Env.Whitelist = append(config.Env.Whitelist, config.Env.Admins...)
		logger.L.Infof("whitelist is enabled: %v", config.Env.Whitelist)
	}

	if config.Env.ProfilerPort > 0 {
		go func() {
			logger.L.Infof("starting profiler on port 6060")
			if err := http.ListenAndServe("0.0.0.0:6060", nil); err != nil {
				logger.L.Fatalf("failed to start profiler: %v", err)
			}
		}()
	}

	if config.Env.MetricsPort > 0 {
		go func() {
			logger.L.Infof("starting prometheus metrics on port 8080")
			http.Handle("/metrics", promhttp.Handler())
			if err := http.ListenAndServe("0.0.0.0:8080", nil); err != nil {
				logger.L.Fatalf("failed to start metrics server: %v", err)
			}
		}()
	}

	localization.Init()
	database.Init()
	util.CleanupDownloadsJob()

	go bot.Start()

	// Keep the main goroutine alive
	select {}
}
