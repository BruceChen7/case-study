package main

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func func1(ctx context.Context) {
	select {
	case <-ctx.Done():
		fmt.Println(ctx.Err())
		return
	default:
	}
	time.Sleep(1 * time.Second)
	deadline, ok := ctx.Deadline()
	if ok {
		remaining := time.Until(deadline)
		fmt.Println("remaining", remaining)
	}
	select {
	case <-ctx.Done():
		fmt.Println(ctx.Err())
		return
	default:
	}
	time.Sleep(3 * time.Second)
}

func func2() {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	now := time.Now()
	go func1(ctx)
	<-ctx.Done()
	t := &testing.T{}
	assert.Equal(t, ctx.Err(), context.DeadlineExceeded)
	elapsed := time.Since(now)
	diff := elapsed - 3*time.Second
	assert.InDelta(t, 0, diff.Milliseconds(), 10, "elapsed should be 3s")
}

func func3() {
	ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(3*time.Second))
	go func1(ctx)
	time.Sleep(1 * time.Second)
	cancel()
}

func main() {
	func2()
	func3()
	time.Sleep(4 * time.Second)
}
