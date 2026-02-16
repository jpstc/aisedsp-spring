# AISEDSP Spring – Architecture Documentation (MZV → STC)

Kombinovaný styl dokumentace (Enterprise + Dev-friendly).

## 1. Overview
Tento projekt implementuje architekturu MZV → STC pomocí Azure komponent.

## 2. Architecture Diagram
Viz `diagrams/architecture.png`.

## 3. Data Flow
Viz `diagrams/flow-mzv-stc.png`.

## 4. Components
Viz `diagrams/components.png`.

## 5. Deployment
Viz `diagrams/deployment.png`.

## 6. Commands
```
azd up
azd deploy --service mzv-service
azd deploy --service stc-cdbp
```
