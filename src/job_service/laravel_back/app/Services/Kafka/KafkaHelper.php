<?php

namespace App\Services\Kafka;

use RdKafka\Conf;
use RdKafka\Producer;
use RdKafka\KafkaConsumer;
use Illuminate\Support\Facades\Log;

class KafkaHelper
{
    private string $brokerList;

    public function __construct()
    {
        // Lấy từ ENV: kafka-0.kafka-svc.job7189-ns.svc.cluster.local:9092
        $this->brokerList = config('services.kafka.brokers', 'kafka:9092');
    }

    /**
     * Gửi tin nhắn (Producer)
     */
    public function produce(string $topicName, array $messageData): void
    {
        $conf = new Conf();
        $conf->set('metadata.broker.list', $this->brokerList);

        $producer = new Producer($conf);
        $topic = $producer->newTopic($topicName);

        $payload = json_encode($messageData);

        // RD_KAFKA_PARTITION_UA: Tự động chọn partition
        $topic->produce(RD_KAFKA_PARTITION_UA, 0, $payload);

        $producer->poll(0);
        
        // Đợi gửi xong (Flush) để đảm bảo không mất tin
        $result = $producer->flush(10000);

        if (RD_KAFKA_RESP_ERR_NO_ERROR !== $result) {
            Log::error("Kafka Produce Failed: " . $result);
            throw new \Exception("Failed to send message to Kafka");
        }
        
        Log::info("Kafka Sent to {$topicName}: $payload");
    }

    /**
     * Tạo Consumer (Trả về instance để chạy vòng lặp)
     */
    public function createConsumer(string $groupId, array $topics): KafkaConsumer
    {
        $conf = new Conf();
        $conf->set('group.id', $groupId);
        $conf->set('metadata.broker.list', $this->brokerList);
        $conf->set('auto.offset.reset', 'earliest'); // Đọc từ đầu nếu chưa có offset
        
        // Tắt auto commit để commit thủ công sau khi xử lý xong (an toàn hơn)
        $conf->set('enable.auto.commit', 'false');

        $consumer = new KafkaConsumer($conf);
        $consumer->subscribe($topics);

        return $consumer;
    }
}