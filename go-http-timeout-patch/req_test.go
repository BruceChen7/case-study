package main

import (
	"bytes"
	"context"
	"log"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestHttpRequestTimeout(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("hello world")
		time.Sleep(5 * time.Second)
	}))
	defer ts.Close()
	// get baidu.com response
	ctx := context.Background()
	ctx, cancel := context.WithTimeout(ctx, 1*time.Second)
	defer cancel()

	go func(ctx context.Context) {
		r := bytes.NewBuffer(make([]byte, 10000))
		req, err := http.NewRequestWithContext(ctx, "GET", ts.URL, r)
		require.NoError(t, err)

		// Create a new HTTP client with a timeout of 10 seconds
		client := &http.Client{
			// Timeout:   3 * time.Second,
			Transport: &http.Transport{
				// set keep-alive
			},
		}
		// use client to send request
		now := time.Now()
		_, err = client.Do(req)
		// elapsed time
		elapsed := time.Since(now)
		sec := elapsed.Seconds()
		require.InDelta(t, 1, sec, 0.1, "timeout is 1 second")
		require.NotNil(t, err)

		// wait ts to complete
		time.Sleep(6 * time.Second)

		newCtx := context.Background()
		req, err = http.NewRequestWithContext(newCtx, "GET", ts.URL, r)
		require.NoError(t, err)

		now = time.Now()
		client = &http.Client{
			Timeout: 2 * time.Second,
		}
		_, err = client.Do(req)
		elapsed = time.Since(now)
		sec = elapsed.Seconds()
		require.InDelta(t, 2, sec, 0.1, "timeout is 2 second")
		require.NotNil(t, err)

	}(ctx)
	time.Sleep(9 * time.Second)

}
