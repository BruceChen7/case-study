package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"time"

	"github.com/segmentio/kafka-go"
	"github.com/testcontainers/testcontainers-go"
	imageKafka "github.com/testcontainers/testcontainers-go/modules/kafka"
)

type kafkaLogConsumer struct {
}

type Kafka struct {
	container testcontainers.Container
	brokers   []string
}

func SetupContainer(ctx context.Context) (*Kafka, func()) {
	kafkaContainer, err := imageKafka.RunContainer(ctx,
		imageKafka.WithClusterID("test-cluster"),
		testcontainers.WithImage("confluentinc/confluent-local:7.5.0"),
	)
	if err != nil {
		panic(err)
	}
	brokers, err := kafkaContainer.Brokers(ctx)
	if err != nil {
		panic(err)
	}

	return &Kafka{
			brokers:   brokers,
			container: kafkaContainer,
		}, func() {
			if err := kafkaContainer.Terminate(context.Background()); err != nil {
				panic(err)
			}
		}
}
func Produce(brokers []string, topic string) {
	conn, err := kafka.DialLeader(context.Background(), "tcp", brokers[0], topic, 0)
	if err != nil {
		panic(err)
	}
	conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	conn.WriteMessages(
		kafka.Message{Value: []byte("one!")},
		kafka.Message{Value: []byte("two!")},
		kafka.Message{Value: []byte("three!")})
	if err := conn.Close(); err != nil {
		panic(err)
	}
}

func Consumer(brokers []string, topic string, exitChan <-chan struct{}) {
	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers: brokers,
		GroupID: "test-group",
		Topic:   topic,
		MaxWait: 1 * time.Second,
	})

	defer func() {
		if err := r.Close(); err != nil {
			panic(err)
		}
	}()
	for {
		select {
		case <-exitChan:
			return
		default:
		}
		fmt.Printf("Waiting for messages...\n")
		msg, err := r.ReadMessage(context.Background())
		if err != nil && err != context.DeadlineExceeded {
			panic(err)
		}
		fmt.Printf("message at topic/partition/offset %v/%v/%v: %s = %s\n", msg.Topic, msg.Partition, msg.Offset, string(msg.Key), string(msg.Value))
		select {
		case <-exitChan:
			return
		default:
		}
	}
}

func main() {
	ctx := context.Background()
	k, cleanup := SetupContainer(ctx)
	defer cleanup()
	Produce(k.brokers, "test-topic")
	// capture ctr-c signal
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	quitSig := make(chan struct{})
	go Consumer(k.brokers, "test-topic", quitSig)

	fmt.Println("Press Ctrl+C to stop")
	<-c
	close(quitSig)
}
