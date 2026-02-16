
package com.aisedsp.mzv.service;

import com.aisedsp.mzv.domain.Document;
import com.azure.messaging.servicebus.*;
import org.springframework.stereotype.Service;

@Service
public class StatusPublisher {
    private final ServiceBusSenderClient sender;

    public StatusPublisher() {
        String conn = System.getenv("SB_CONN");
        String topic = System.getenv().getOrDefault("SB_TOPIC", "doc-status");
        this.sender = new ServiceBusClientBuilder()
            .connectionString(conn)
            .sender()
            .topicName(topic)
            .buildClient();
    }

    public void publish(Document doc) {
        String payload = String.format("{"id":%d,"title":"%s","status":"%s"}",
                doc.getId(), doc.getTitle(), doc.getStatus());
        sender.sendMessage(new ServiceBusMessage(payload));
    }
}
