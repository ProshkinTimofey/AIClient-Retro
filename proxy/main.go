package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Config holds proxy configuration
type Config struct {
	ListenAddr   string
	TargetHost   string
	TargetScheme string
	CertFile     string
	KeyFile      string
	Verbose      bool
}

func main() {
	cfg := &Config{}

	flag.StringVar(&cfg.ListenAddr, "listen", ":8080", "HTTP listen address (iOS 6 connects here)")
	flag.StringVar(&cfg.TargetHost, "target", "api.openai.com", "Target API hostname")
	flag.StringVar(&cfg.TargetScheme, "scheme", "https", "Target scheme (https)")
	flag.StringVar(&cfg.CertFile, "cert", "", "TLS cert file (optional, for HTTPS to iOS 6)")
	flag.StringVar(&cfg.KeyFile, "key", "", "TLS key file (optional)")
	flag.BoolVar(&cfg.Verbose, "v", false, "Verbose logging")
	flag.Parse()

	// Build target URL
	targetURL := &url.URL{
		Scheme: cfg.TargetScheme,
		Host:   cfg.TargetHost,
	}

	log.Printf("Starting AIClient TLS Proxy")
	log.Printf("  Listen: %s (HTTP%s)", cfg.ListenAddr, ternary(cfg.CertFile != "", "S", ""))
	log.Printf("  Target: %s", targetURL.String())
	log.Printf("  iOS 6 TLS: 1.0/1.1 -> Proxy -> TLS 1.2+ to %s", cfg.TargetHost)

	// Create reverse proxy
	proxy := httputil.NewSingleHostReverseProxy(targetURL)

	// Custom director to handle headers correctly
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.Host = targetURL.Host

		// Forward original headers, but ensure we don't pass problematic ones
		req.Header.Del("Accept-Encoding") // We handle compression

		if cfg.Verbose {
			log.Printf("→ %s %s %s", req.Method, req.URL.Path, req.Proto)
		}
	}

	// Handle streaming responses properly
	proxy.ModifyResponse = func(resp *http.Response) error {
		if cfg.Verbose {
			log.Printf("← %d %s", resp.StatusCode, resp.Request.URL.Path)
		}

		// For streaming responses, disable compression so we can pass through
		if strings.Contains(resp.Header.Get("Content-Type"), "text/event-stream") {
			resp.Header.Del("Content-Encoding")
			resp.Header.Del("Content-Length")
			resp.ContentLength = -1
		}

		return nil
	}

	// Error handler
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("Proxy error: %v", err)
		http.Error(w, "Bad Gateway", http.StatusBadGateway)
	}

	// Transport with TLS config for upstream
	proxy.Transport = &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		ForceAttemptHTTP2:     true,
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		TLSClientConfig: &tls.Config{
			// Modern TLS for upstream
			MinVersion: tls.VersionTLS12,
			ServerName: targetURL.Host,
		},
	}

	// Create HTTP server
	server := &http.Server{
		Addr:         cfg.ListenAddr,
		Handler:      proxy,
		ReadTimeout:  300 * time.Second, // Long for streaming
		WriteTimeout: 300 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		log.Println("Shutting down...")
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		server.Shutdown(ctx)
	}()

	// Start server
	var err error
	if cfg.CertFile != "" && cfg.KeyFile != "" {
		log.Println("Serving HTTPS (for iOS 6 with old TLS)...")
		err = server.ListenAndServeTLS(cfg.CertFile, cfg.KeyFile)
	} else {
		log.Println("Serving HTTP (iOS 6 connects here)...")
		err = server.ListenAndServe()
	}

	if err != http.ErrServerClosed {
		log.Fatalf("Server failed: %v", err)
	}
	log.Println("Server stopped gracefully")
}

func ternary(cond bool, a, b string) string {
	if cond {
		return a
	}
	return b
}

// ---- Optional: Simple standalone streaming proxy without httputil ----

// StreamingProxy is a simpler proxy that handles SSE streaming correctly
type StreamingProxy struct {
	target  *url.URL
	client  *http.Client
	verbose bool
}

func NewStreamingProxy(targetURL *url.URL, verbose bool) *StreamingProxy {
	return &StreamingProxy{
		target: targetURL,
		client: &http.Client{
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					MinVersion: tls.VersionTLS12,
					ServerName: targetURL.Host,
				},
			},
			Timeout: 0, // No timeout for streaming
		},
		verbose: verbose,
	}
}

func (p *StreamingProxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Build target request
	targetReq, err := http.NewRequest(r.Method, p.target.ResolveReference(r.URL).String(), r.Body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Copy headers
	for k, v := range r.Header {
		// Skip hop-by-hop headers
		if k == "Connection" || k == "Keep-Alive" || k == "Proxy-Authenticate" ||
			k == "Proxy-Authorization" || k == "Te" || k == "Trailers" ||
			k == "Transfer-Encoding" || k == "Upgrade" {
			continue
		}
		for _, vv := range v {
			targetReq.Header.Add(k, vv)
		}
	}
	targetReq.Host = p.target.Host

	if p.verbose {
		log.Printf("→ %s %s", r.Method, r.URL.Path)
	}

	// Send request
	resp, err := p.client.Do(targetReq)
	if err != nil {
		log.Printf("Upstream error: %v", err)
		http.Error(w, "Bad Gateway", http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	if p.verbose {
		log.Printf("← %d %s", resp.StatusCode, r.URL.Path)
	}

	// Copy response headers
	for k, v := range resp.Header {
		// Skip hop-by-hop
		if k == "Connection" || k == "Keep-Alive" || k == "Transfer-Encoding" {
			continue
		}
		for _, vv := range v {
			w.Header().Add(k, vv)
		}
	}
	w.WriteHeader(resp.StatusCode)

	// Stream body
	// For SSE, we need to flush after each line
	if strings.Contains(resp.Header.Get("Content-Type"), "text/event-stream") {
		p.streamSSE(w, resp.Body)
	} else {
		io.Copy(w, resp.Body)
	}
}

func (p *StreamingProxy) streamSSE(w http.ResponseWriter, body io.Reader) {
	// Wrap response writer to flush after each write
	flusher, ok := w.(http.Flusher)
	if !ok {
		io.Copy(w, body)
		return
	}

	reader := bufio.NewReader(body)
	buf := make([]byte, 4096)

	for {
		n, err := reader.Read(buf)
		if n > 0 {
			w.Write(buf[:n])
			flusher.Flush()
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Printf("Stream read error: %v", err)
			break
		}
	}
}

// OpenAI-compatible models endpoint for NIM discovery
func handleModels(w http.ResponseWriter, r *http.Request) {
	// Return OpenAI-compatible models list
	models := map[string]interface{}{
		"object": "list",
		"data": []map[string]interface{}{
			{"id": "meta/llama-3.1-405b-instruct", "object": "model", "owned_by": "nvidia"},
			{"id": "meta/llama-3.1-70b-instruct", "object": "model", "owned_by": "nvidia"},
			{"id": "meta/llama-3.1-8b-instruct", "object": "model", "owned_by": "nvidia"},
			{"id": "nvidia/nemotron-3-ultra", "object": "model", "owned_by": "nvidia"},
			{"id": "mistralai/mixtral-8x22b-instruct", "object": "model", "owned_by": "nvidia"},
			{"id": "google/gemma-2-27b-it", "object": "model", "owned_by": "nvidia"},
			{"id": "microsoft/phi-3-medium-128k-instruct", "object": "model", "owned_by": "nvidia"},
		},
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models)
}