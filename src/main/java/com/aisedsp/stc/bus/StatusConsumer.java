
package com.aisedsp.stc.bus;

import com.aisedsp.stc.domain.StcEvent;
import com.aisedsp.stc.repo.StcEventRepository;
import com.azure.messaging.servicebus.*;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger; import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

@Component
public class StatusConsumer {
    private static final Logger log = LoggerFactory.getLogger(StatusConsumer.class);

    private final ServiceBusProcessorClient processor;
    private final StcEventRepository repo;
    private final List<String> inMemory = Collections.synchronizedList(new LinkedList<>());

    public StatusConsumer(StcEventRepository repo) {
        this.repo = repo;
        String conn = System.getenv("SB_CONN");
        String topic = System.getenv().getOrDefault("SB_TOPIC", "doc-status");
        String sub   = System.getenv().getOrDefault("SB_SUB", "stc-cdbp");

        this.processor = new ServiceBusClientBuilder()
            .connectionString(conn)
            .processor()
            .topicName(topic)
            .subscriptionName(sub)
            .processMessage(ctx -> {
                ServiceBusReceivedMessage m = ctx.getMessage();
                String body = m.getBody().toString();
                String subject = m.getSubject();

                // A) log do konzole
                log.info("CDBP received (subject={}): {}", subject, body);

                // B) in-memory buffer pro rychlý náhled
                inMemory.add(body);
                if (inMemory.size() > 100) inMemory.remove(0);

                // C) zápis do SQL
                StcEvent e = new StcEvent();
                e.setSubject(subject);
                e.setPayload(body);
                repo.save(e);

                ctx.complete();
            })
            .processError(err -> log.error("CDBP error: {}", err.getException().getMessage()))
            .buildProcessorClient();
    }

    @PostConstruct public void start(){ processor.start(); }
    @PreDestroy  public void stop(){ processor.close(); }

    public List<String> getInMemory(){ return inMemory; }
}
