
package com.aisedsp.stc.api;

import com.aisedsp.stc.repo.StcEventRepository;
import com.aisedsp.stc.bus.StatusConsumer;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;

@RestController
@RequestMapping("/api/stc")
public class StcController {
    private final StatusConsumer consumer;
    private final StcEventRepository repo;

    public StcController(StatusConsumer consumer, StcEventRepository repo) {
        this.consumer = consumer;
        this.repo = repo;
    }

    @GetMapping("/ping")
    public String ping(){ return "stc-ok"; }

    @GetMapping("/messages")
    public ResponseEntity<?> inMemory(){ return ResponseEntity.ok(consumer.getInMemory()); }

    @GetMapping("/messages/sql")
    public ResponseEntity<?> sql(){ return ResponseEntity.ok(repo.findAll()); }
}
