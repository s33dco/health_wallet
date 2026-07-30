# Thin wrapper around Import::Processor: load the record, mark progress, delegate the actual
# work, and translate outcomes into the LabImport's status so the UI can report them.
class LabResultImportJob < ApplicationJob
  queue_as :default

  def perform(lab_import_id)
    lab_import = LabImport.find(lab_import_id)

    # Download once; use it both to fingerprint the file and to import it.
    content = lab_import.file.download
    lab_import.update!(file_checksum: Digest::SHA256.hexdigest(content))

    if lab_import.duplicate_of
      lab_import.mark_duplicate!
      return
    end

    lab_import.mark_processing!

    result = Import::Processor.new(content).call

    lab_import.mark_completed!(result.to_h)
  rescue Hl7LabResultParser::ParseError => e
    # Bad input data — the file is rejected as designed. Recoverable, not an incident.
    lab_import.mark_failed!("Parse error: #{e.message}")
  rescue => e
    # Something we didn't anticipate — record it, then re-raise so error tracking/retries see it.
    lab_import.mark_failed!("Unexpected error: #{e.message}")
    raise
  end
end
