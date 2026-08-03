# Thin wrapper around Import::Processor: load the record, mark progress, delegate the actual
# work, and translate outcomes into the LabImport's status so the UI can report them.
class LabResultImportJob < ApplicationJob
  queue_as :default

  def perform(lab_import_id)
    lab_import = LabImport.find(lab_import_id)
    log(:info, event: "import_started", lab_import_id: lab_import.id, filename: lab_import.file.filename.to_s)

    # Download once; use it both to fingerprint the file and to import it.
    content = lab_import.file.download
    lab_import.update!(file_checksum: Digest::SHA256.hexdigest(content))

    if (duplicate = lab_import.duplicate_of)
      log(:info, event: "duplicate_import_detected", lab_import_id: lab_import.id,
                 duplicate_of_id: duplicate.id, checksum: lab_import.file_checksum)
      lab_import.mark_duplicate!
      return
    end

    begin
      lab_import.mark_processing!
    rescue ActiveRecord::RecordNotUnique
      # Another import with the same checksum won the race to start processing first (the
      # `duplicate_of` check above only sees *completed* imports, so it can't catch two still
      # in flight). The partial unique index on lab_imports lets exactly one of them through.
      log(:info, event: "duplicate_import_detected", lab_import_id: lab_import.id, checksum: lab_import.file_checksum)
      lab_import.mark_duplicate!
      return
    end

    result = Import::Processor.new(content).call

    lab_import.mark_completed!(result.to_h)
    log(:info, event: "import_completed", lab_import_id: lab_import.id, **result.to_h)
  rescue Hl7LabResultParser::ParseError => e
    # Bad input data — the file is rejected as designed. Recoverable, not an incident.
    log(:warn, event: "import_parse_error", lab_import_id: lab_import.id, message: e.message)
    lab_import.mark_failed!("Parse error: #{e.message}")
  rescue => e
    # Something we didn't anticipate — record it, then re-raise so error tracking/retries see it.
    log(:error, event: "import_unexpected_error", lab_import_id: lab_import.id,
                error_class: e.class.name, message: e.message)
    lab_import.mark_failed!("Unexpected error: #{e.message}")
    raise
  end

  private

  # Emit key-value pairs as JSON rather than a free-text string, so log lines stay
  # filterable/queryable in a log aggregator (Datadog, ELK, ...) without string parsing.
  def log(level, **payload)
    Rails.logger.public_send(level, payload.to_json)
  end
end
