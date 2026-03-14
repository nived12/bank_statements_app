# Vittio Synthetic Workforce (AGENTS.md)

## Overview
This document defines the cognitive roles within the Vittio ecosystem. We treat agents as specialized employees with defined responsibilities and strict output contracts.

## Active Agents

### 1. The Financial Auditor (The "Categorizer")
- **Location:** `vittio_brain/agents/auditor.py`
- **Tech:** Python 3.12, PydanticAI.
- **Responsibility:** - Parse raw text/OCR into structured JSON.
    - Categorize transactions using user-specific historical data.
    - Assign confidence scores to every field.
- **Success Metric:** >98% schema compliance; <2% hallucination rate on merchant names.

### 2. The OCR Vision Specialist (The "Parser")
- **Location:** `vittio_brain/agents/vision_specialist.py`
- **Responsibility:** - Handle PDF-to-text conversion for complex layouts (Santander, BBVA, etc.).
    - Normalize fragmented OCR data.

## Shared Tools & Reasoning
- **Memory:** Agents query the Rails API `/api/v1/categories` to understand the user's personal taxonomy.
- **Validation Loop:** If confidence < 0.8, the agent triggers a "Reflection" step to double-check the description against known merchant patterns.

## Evaluation Strategy (Evals)
We use **LangSmith** to track agent performance. Every prompt change must be tested against `spec/fixtures/bank_statements/` to ensure no regression in categorization accuracy.
