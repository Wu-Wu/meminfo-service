package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

type MemInfo struct {
	Total int `json:"total"`
	Avail int `json:"avail"`
	Used  int `json:"used"`
}

func main() {
	log.Printf("starting the meminfo service")
	defer log.Printf("stopping the meminfo service")

	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	router := http.NewServeMux()
	router.HandleFunc("/meminfo", meminfoHandler)

	srv := &http.Server{
		Addr:    ":1027",
		Handler: router,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen error: %s", err)
		}
	}()

	<-done

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("server shutdown failed: %s", err)
	}
}

func meminfoHandler(w http.ResponseWriter, r *http.Request) {
	mi := MemInfo{}
	f, e := os.Open("/node-meminfo")
	if e != nil {
		panic(e)
	}
	defer f.Close()
	s := bufio.NewScanner(f)
	for s.Scan() {
		var n int
		if nItems, _ := fmt.Sscanf(s.Text(), "MemTotal: %d kB", &n); nItems == 1 {
			mi.Total = n * 1024
		}
		if nItems, _ := fmt.Sscanf(s.Text(), "MemAvailable: %d kB", &n); nItems == 1 {
			mi.Avail = n * 1024
		}
	}
	if mi.Total > 0 && mi.Avail > 0 {
		mi.Used = mi.Total - mi.Avail
	}

	jsonData, err := json.Marshal(mi)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(jsonData)
}
