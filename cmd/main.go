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

	// 1. Load initial config
	config.Load()

	// 2. FORCE DATABASE CONNECTION FROM RENDER ENV
	// This replaces the default 'db' host with your actual Render Postgres URL
	if os.Getenv("DATABASE_URL") != "" {
		config.Env.DatabaseURL = os.Getenv("DATABASE_URL")
	}

	logger.SetLevel(config.Env.LogLevel)

	// 3. Check for FFmpeg (Requirement for video processing)
	if !util.CheckFFmpeg() {
		logger.L.Fatal("ffmpeg binary not found in PATH")
	}

	// 4. RENDER HEALTH CHECK SERVER
	// This prevents Render from timing out your deployment
	go func() {
		port := os.Getenv("PORT")
		if port == "" {
			port = "10000" // Default for Render
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

	// 5. Admin and Whitelist Setup
	if len(config.Env.Admins) > 0 {
		logger.L.Infof("admins: %v", config.Env.Admins)
	}

	if len(config.Env.Whitelist) > 0 {
		config.Env.Whitelist = append(config.Env.Whitelist, config.Env.Admins...)
		logger.L.Infof("whitelist is enabled: %v", config.Env.Whitelist)
	}

	// 6. Optional Profiler
	if config.Env.ProfilerPort > 0 {
		go func() {
			logger.L.Infof("starting profiler on port 6060")
			if err := http.ListenAndServe("0.0.0.0:6060", nil); err != nil {
				logger.L.Fatalf("failed to start profiler: %v", err)
			}
		}()
	}

	// 7. Optional Metrics
	if config.Env.MetricsPort > 0 {
		go func() {
			logger.L.Infof("starting prometheus metrics on port 8080")
			http.Handle("/metrics", promhttp.Handler())
			if err := http.ListenAndServe("0.0.0.0:8080", nil); err != nil {
				logger.L.Fatalf("failed to start metrics server: %v", err)
			}
		}()
	}

	// 8. Initialize Subsystems
	localization.Init()
	database.Init() // Migrations run here; now they will use DATABASE_URL
	util.CleanupDownloadsJob()

	// 9. Start the Bot
	go bot.Start()

	// Keep the process alive
	select {}
}
