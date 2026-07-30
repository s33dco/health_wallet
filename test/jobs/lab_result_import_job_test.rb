require "test_helper"

class LabResultImportJobTest < ActiveSupport::TestCase
  setup do
    ObservationCode.create!(code: "8480-6", description: "Blood Pressure (Systolic)")
  end

  def lab_import_with(content)
    lab_import = LabImport.create!
    lab_import.file.attach(io: StringIO.new(content), filename: "labs.txt", content_type: "text/plain")
    lab_import
  end

  test "processes a valid file, imports records, and marks the import completed" do
    lab_import = lab_import_with("John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|mmHg\n")

    LabResultImportJob.perform_now(lab_import.id)

    assert lab_import.reload.completed?
    assert_equal 1, Patient.count
    assert_equal 1, Patient.first.assessments.first.observations.count
  end

  test "stores a structured summary of what the import did" do
    lab_import = lab_import_with("John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|mmHg\n")

    LabResultImportJob.perform_now(lab_import.id)

    summary = lab_import.reload.summary
    assert_equal 1, summary["patients_created"]
    assert_equal 1, summary["assessments_created"]
    assert_equal 1, summary["observations_created"]
  end

  test "re-importing an identical file is detected as a duplicate and skipped" do
    content = "John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|mmHg\n"
    first = lab_import_with(content)
    LabResultImportJob.perform_now(first.id)
    assert first.reload.completed?

    second = lab_import_with(content) # same bytes
    LabResultImportJob.perform_now(second.id)

    assert second.reload.duplicate?
    assert_equal 1, Patient.count # the second import created nothing
    assert_equal first.file_checksum, second.file_checksum
  end

  test "marks the import failed with a parse-error message on bad input" do
    lab_import = lab_import_with("John Doe|1985-03-15|M|REF-2024-001\n9999-9|120|mmHg\n")

    LabResultImportJob.perform_now(lab_import.id)

    assert lab_import.reload.failed?
    assert_match(/Parse error/, lab_import.error_message)
    assert_equal 0, Patient.count
  end
end
