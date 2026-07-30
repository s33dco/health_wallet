# Implementation Summary — HL7 Lab Result Import

This document records the design decisions behind the lab-result import feature and notes
where AI assistance was used. It is written incrementally: each commit that introduces a
decision appends the reasoning here, so this file's own history mirrors the commit story.

## Approach

The task (`FHM_CODING_TASK.md`) asks for a web upload that triggers a background job to
parse a simplified HL7 file and create/update `Patient` / `Assessment` / `Observation`
records. I built the literal spec end-to-end first, then layered a small number of
deliberate enhancements — each as its own isolated, reviewable commit — because the
enhancements reflect real concerns in a clinical data system rather than scope creep. Each
is called out below so the line between "required" and "deliberate extension" stays clear.

The design separates concerns into small, independently testable pieces:

- **`Hl7LabResultParser`** — a standalone object that turns file text into plain structs.
  No database, no framework; trivially unit-testable.
- **`Import::Processor`** — a framework-agnostic object holding the find-or-create rules.
- **`LabResultImportJob`** — a thin ActiveJob wrapper: load record, delegate, handle failure.
- **`LabImport`** — an ActiveRecord model tracking one upload's lifecycle (status, errors).
- **`ObservationCode`** — Mongoid reference data (the controlled LOINC vocabulary).

## Data model choices

- **`ObservationCode` is Mongoid.** LOINC codes are part of the clinical domain, so they
  live alongside the other Mongoid documents. A unique index on `code` enforces that the
  controlled vocabulary has no duplicates; presence validation guards `code`/`description`.
- The importer treats these codes as a **controlled vocabulary**: an incoming HL7 code that
  is not seeded is rejected rather than silently created, so unknown/typo'd codes fail loud.

## Testing notes

- Tests are intentionally **not parallelized** (`test/test_helper.rb`). ActiveRecord gives
  each parallel worker its own SQLite database, but Mongoid points every worker at the one
  `health_wallet_test` database; the shared `Mongoid.purge!` would let workers wipe each
  other's in-flight data. Running single-threaded keeps the Mongo-backed tests deterministic.

## AI assistance

AI (Claude) assisted with drafting the parser/processor/job structure, the test suites, and
this document. All design decisions were reviewed and directed by me; the AI-generated code
was validated by running the feature end-to-end and the full test suite.
