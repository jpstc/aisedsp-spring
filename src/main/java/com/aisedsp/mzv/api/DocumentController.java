
package com.aisedsp.mzv.api;

import com.aisedsp.mzv.domain.Document;
import com.aisedsp.mzv.repo.DocumentRepository;
import com.aisedsp.mzv.service.StatusPublisher;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import java.net.URI;

@RestController
@RequestMapping("/api/documents")
public class DocumentController {

    private final DocumentRepository repo;
    private final StatusPublisher publisher;

    public DocumentController(DocumentRepository repo, StatusPublisher publisher) {
        this.repo = repo;
        this.publisher = publisher;
    }

    @PostMapping
    public ResponseEntity<Document> create(@Valid @RequestBody Document d) {
        var saved = repo.save(d);
        publisher.publish(saved);
        return ResponseEntity.created(URI.create("/api/documents/" + saved.getId())).body(saved);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Document> get(@PathVariable Long id) {
        return repo.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<Document> update(@PathVariable Long id, @Valid @RequestBody Document dto) {
        return repo.findById(id).map(e -> {
            e.setTitle(dto.getTitle());
            e.setStatus(dto.getStatus());
            var saved = repo.save(e);
            publisher.publish(saved);
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if (!repo.existsById(id)) return ResponseEntity.notFound().build();
        repo.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
