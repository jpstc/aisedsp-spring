
package com.aisedsp.stc.domain;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
public class StcEvent {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 50)
    private String subject;    // e.g., DocumentStatusChanged

    @Column(columnDefinition = "nvarchar(max)")
    private String payload;    // raw JSON

    private OffsetDateTime receivedAt = OffsetDateTime.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getSubject() { return subject; }
    public void setSubject(String subject) { this.subject = subject; }

    public String getPayload() { return payload; }
    public void setPayload(String payload) { this.payload = payload; }

    public OffsetDateTime getReceivedAt() { return receivedAt; }
    public void setReceivedAt(OffsetDateTime receivedAt) { this.receivedAt = receivedAt; }
}
