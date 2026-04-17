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

	// 1. Load initial config (this usually defaults to 'db')
	config.Load()

	// 2. HARD OVERRIDE: Force Render's DATABASE_URL into the config struct
	// Based on internal/config/env.go, the field name is 'DB'
	if renderDB := os.Getenv("DATABASE_URL"); renderDB != "" {
		config.Env.DB = renderDB
		logger.L.Info("Database URL successfully overridden from environment")
	}

	logger.SetLevel(config.Env.LogLevel)

	if !util.CheckFFmpeg() {
		logger.L.Fatal("ffmpeg binary not found in PATH")
	}

	// 3. RENDER HEALTH CHECK SERVER
	go func() {
		port := os.Getenv("PORT")
		if port == "" {
			port = "10000"
		}
		logger.L.Infof("Starting health check server on port %s", port)
		
		mux := http.NewServeMux()
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			fmt.Fprint(w, "OK")
		})
		
		if err := http.ListenAndServe(":"+port, mux); err != nil {
			logger.L.Errorf("Health check server failed: %v", err)
		}
	}()

	if len(config.Env.Admins) > 0 {
		logger.L.Infof("admins: %v", config.Env.Admins)
	}

	if len(config.Env.Whitelist) > 0 {
		config.Env.Whitelist = append(config.Env.Whitelist, config.Env.Admins...)
		logger.L.Infof("whitelist is enabled: %v", config.Env.Whitelist)
	}

	if config.Env.ProfilerPort > 0 {
		go func() {
			if err := http.ListenAndServe("0.0.0.0:6060", nil); err != nil {
				logger.L.Fatalf("failed to start profiler: %v", err)
			}
		}()
	}

	if config.Env.MetricsPort > 0 {
		go func() {
			http.Handle("/metrics", promhttp.Handler())
			if err := http.ListenAndServe("0.0.0.0:8080", nil); err != nil {
				logger.L.Fatalf("failed to start metrics server: %v", err)
			}
		}()
	}

	// 4. Initialize Subsystems
	localization.Init()
	database.Init() // This will now use the overridden config.Env.DB
	util.CleanupDownloadsJob()

	go bot.Start()

	select {}
}