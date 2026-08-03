# Implementation Summary — HL7 Lab Result Import

This document records the design decisions behind the lab-result import feature and notes
where AI assistance was used. The literal spec was built end to end first; each deliberate
extension then landed as its own isolated commit, so the git log tells the same story this
document does.

## Summary of changes

Adds an HL7 lab-result import feature to the existing app:

- **Upload + background import (the literal task).** A `/lab_imports` upload page enqueues
  `LabResultImportJob`, which parses a simplified HL7 file and creates or updates
  `Patient` / `Assessment` / `Observation` records per the spec's find-or-create rules. A
  status page reports progress, and imported results appear on the existing assessment pages.
- **New building blocks.** `Hl7LabResultParser` (parsing), `Import::Processor` (the
  find-or-create rules), `LabImport` (an ActiveRecord + Active Storage lifecycle record), and
  `ObservationCode` Mongoid reference data seeded with the LOINC codes.
- **Deliberate extensions**, each its own commit: an observation audit trail with a
  history-disclosure UI (covering both imports and manual edits), a structured import
  summary, units-aware out-of-range flagging, checksum-based duplicate detection, structured
  logging, and a paginated lab-imports index.
- **Tests** across the parser, processor, models, job, and controllers (green on Ruby 3.4.8).

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

## Parser (`Hl7LabResultParser`)

- Standalone and framework-agnostic — returns plain `Struct`s, touches no database (beyond
  looking up the `ObservationCode` vocabulary), so it is unit-testable in isolation.
- A **4-field line always starts a new patient/assessment block**; the 3-field lines that
  follow are its observations (matches the `Multiple_Patients` example).
- **Fails loud on bad input**: unknown LOINC codes, unknown sex codes, unparseable dates,
  and malformed field counts all raise `ParseError` rather than being silently skipped. One
  bad line fails the whole file — a simple, safe default for clinical data.
- Uses `ObservationCode.where(code:).first` rather than `find_by`, because Mongoid's
  `find_by` raises `DocumentNotFound`; we want a missing code to surface as our `ParseError`.

## Import orchestration (`Import::Processor`)

- A plain object holding the spec's find-or-create rules, so the logic is testable without
  ActiveJob or a controller. The background job is a thin wrapper around it.
- Implements the three rules exactly: Patient by `name + dob + sex_at_birth`, Assessment by
  `reference` within patient, Observation by `code` within assessment (update value/units
  or create). Re-importing the same file is idempotent (records are matched, not duplicated).
- The HL7 file carries no assessment date, so a newly created assessment is stamped with the
  import date via `Date.current.to_s` (zone-aware) rather than `Date.today` (server-local).
- Returns a `Result` struct of create/match counts, read through a `Hash.new(0)` so untouched
  counters report `0` rather than `nil`.

## Upload lifecycle (`LabImport` + `LabResultImportJob`)

- **`LabImport` is ActiveRecord (SQLite), deliberately.** It is an operational/audit record
  of an upload's lifecycle, not clinical data, so it gets Active Storage's `has_one_attached`
  for free with no BSON/polymorphic-id friction against Mongoid. `ObservationCode` stays in
  Mongoid because LOINC codes are genuinely part of the clinical domain. (Active Storage's
  tables were installed via `active_storage:install`, which also bootstrapped the app's first
  ActiveRecord migration/schema.)
- **`status` is an integer enum with an explicit hash mapping** (`{ pending: 0, ... }`) rather
  than the array shorthand, so adding a status later can't silently renumber existing rows.
  Predicate methods (`completed?`), bang transitions (`processing!`) and scopes come for free.
- **The job is a thin wrapper.** It marks the import processing, delegates to
  `Import::Processor`, and marks it completed — translating a `ParseError` into a `failed`
  status with a human message (recoverable, expected) while re-raising anything unexpected
  after recording it (so retries/error tracking still fire).

## Web interface

- `LabImportsController` exposes `new`/`create`/`show` (plus the `index` added later, below).
  Upload attaches the file, saves the `LabImport`, enqueues `LabResultImportJob.perform_later`,
  and redirects to the status page. Uploading no file re-renders the form with an error.
- The status page keys a CSS class off the enum (`status--completed`, `status--failed`, …) so
  each state is styled in CSS without per-state Ruby, and auto-refreshes (meta refresh) only
  while the import is still pending/processing. Imported observations appear on the existing
  patient/assessment pages, satisfying the "visible in the patient's assessment page" requirement.
- In development the job runs on the in-process `:async` adapter (only production configures
  Solid Queue), so uploads process without a separate worker.

## Deliberate extensions beyond the spec

Each of these is a separate, isolated commit on top of the spec-complete feature.

- **Audit trail for corrections (the standout piece).** Taken literally, the spec's
  "update value/units" rule means a corrected or re-run lab result silently overwrites
  history. That's a real gap in a clinical system. An embedded `ObservationHistory` plus
  `Observation#record_reading!` append every reading to a trail before updating the
  current value; `value`/`units` stay the fast-access current state (satisfying the literal
  rule). Manual edits on the assessment page route through the same method (tagged source
  `manual_edit` vs `hl7_import`), so UI corrections are audited too, and the assessment
  page surfaces the trail as a click-to-expand `<details>` disclosure (native, no JS, and
  it expands inline so the table's `overflow: hidden` can't clip it).
- **Structured import summary.** `LabImport` stores a JSON summary of what actually
  happened (records created vs. matched/updated, plus any flagged results), shown on the
  status page instead of a bare "completed".
- **Out-of-range flagging, units-aware.** `ObservationCode` carries an optional reference
  range in a canonical unit; readings outside it are flagged (but still imported —
  out-of-range is clinically interesting, not invalid). A small `UnitConverter` normalizes
  the reading first (°F↔°C), so a normal 98.6°F reading isn't falsely flagged against a
  Celsius range, and the check never flags when a unit can't be converted rather than
  guessing.
- **Duplicate-upload detection.** A SHA256 checksum fingerprints each file; a new upload
  matching a prior *completed* import is marked `duplicate` and skipped without touching
  records. Only completed imports count, so a prior failure never blocks a genuine retry.
- **Structured logging.** The job emits key-value JSON events (`import_started`,
  `duplicate_import_detected`, `import_completed`, `import_parse_error`,
  `import_unexpected_error`) at info/warn/error levels, so logs stay queryable in an
  aggregator without string parsing.
- **Paginated lab imports index.** A browsable list of all uploads (filename, status,
  time), paginated with dependency-free offset/limit rather than pulling in a gem.

## Known limitations / trade-offs

Named here rather than built, to keep scope honest:

- **Concurrency.** Two simultaneous imports of the same *new* patient could race, since
  there is no unique compound index on `Patient` (`name`+`dob`+`sex_at_birth`) or
  `Assessment` (`patient`+`reference`). Likewise, duplicate detection only matches against
  already-*completed* imports, so two identical files uploaded at once could both process.
- **Transaction scope.** Each embedded-document write (`Observation`/`ObservationHistory`
  within `Assessment`) is atomic at the parent-document level; there is no multi-document
  transaction spanning `Patient`/`Assessment`/`Observation`.
- **One bad line fails the whole file.** A deliberate, documented default — simple and safe
  for clinical data — rather than partially importing a malformed file.

## Encoding note (bug caught during end-to-end verification)

Active Storage's `file.download` returns an **ASCII-8BIT** string. Units like `°F` are valid
UTF-8 bytes, but left tagged as binary they raise `Encoding::UndefinedConversionError` when
Mongoid serializes them to BSON (UTF-8). The parser now reinterprets input as UTF-8 up front
and rejects genuinely invalid bytes with a `ParseError`. The unit tests missed this because
their heredocs were already UTF-8; running the real upload path surfaced it.

## Testing notes

- Tests are intentionally **not parallelized** (`test/test_helper.rb`). ActiveRecord gives
  each parallel worker its own SQLite database, but Mongoid points every worker at the one
  `health_wallet_test` database; the shared `Mongoid.purge!` would let workers wipe each
  other's in-flight data. Running single-threaded keeps the Mongo-backed tests deterministic.
- Each unit is covered at the level it lives — parser, processor, models, job, and
  controllers — and the whole suite runs green on Ruby 3.4.8 (the version CI uses via
  `.ruby-version`), with RuboCop and Brakeman clean.

## AI assistance

The implementation was carried out with AI assistance (Claude Code) throughout. I owned the
architecture and every design and product decision — captured in a design sketch before any
code was written, including the `ObservationHistory` audit trail, the units-aware
`ObservationCode`/`UnitConverter` approach, checksum-based duplicate detection, and the
decision to back `LabImport` with ActiveRecord/Active Storage rather than Mongoid (it's an
operational record, not clinical domain data). I reviewed each change, ran the full test
suite, and drove the feature end to end against the sample files, correcting course where
needed. Two examples of that review adding value:

- **Units-aware range checking.** My initial Body Temperature range was in Celsius, but the
  task's own `John_Doe_HL7.txt` reports Fahrenheit (98.6°F); comparing directly would have
  flagged a perfectly normal reading. I added a canonical unit and a small `UnitConverter`
  so values are normalized before comparison, and the check never flags when a unit can't be
  converted rather than guessing.
- **Audit trail on manual edits.** The first cut only recorded history on import; I caught
  that the assessment edit form bypassed it and had the edit path route through the same
  `record_reading!` (tagged `manual_edit`), so UI corrections are audited too.

Working to that direction, Claude Code wrote essentially all of the code and tests: the
parser, `Import::Processor`, the background job, the `LabImport` model, the controllers and
views, and each of the deliberate extensions above.

This mirrors how I use AI tooling day to day: I own the design and the judgment calls, AI
accelerates the implementation, and I stay accountable for reviewing and validating what it
produces before it ships.
