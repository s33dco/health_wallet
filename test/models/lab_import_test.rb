require "test_helper"

class LabImportTest < ActiveSupport::TestCase
  test "defaults to pending status on a new record" do
    assert LabImport.new.pending?
  end

  test "exposes a predicate method for every defined status" do
    %i[pending processing completed failed].each do |status|
      assert LabImport.new(status: status).public_send("#{status}?"),
             "expected #{status}? to be true when status is #{status}"
    end
  end

  test "raises ArgumentError when assigned a status outside the enum" do
    assert_raises(ArgumentError) { LabImport.new(status: "not_a_real_status") }
  end

  test "mark_processing! transitions from pending to processing and persists" do
    lab_import = LabImport.create!(status: :pending)

    lab_import.mark_processing!

    assert lab_import.processing?
    assert lab_import.reload.processing?
  end

  test "mark_completed! transitions to completed and persists" do
    lab_import = LabImport.create!(status: :processing)

    lab_import.mark_completed!

    assert lab_import.reload.completed?
  end

  test "mark_failed! transitions to failed and stores the error message" do
    lab_import = LabImport.create!(status: :processing)

    lab_import.mark_failed!("Parse error: Unknown observation code")

    assert lab_import.failed?
    assert_equal "Parse error: Unknown observation code", lab_import.reload.error_message
  end

  test "scopes filter by status" do
    LabImport.create!(status: :completed)
    LabImport.create!(status: :failed)
    LabImport.create!(status: :failed)

    assert_equal 1, LabImport.completed.count
    assert_equal 2, LabImport.failed.count
  end

  test "accepts an attached file" do
    lab_import = LabImport.new
    lab_import.file.attach(io: StringIO.new("John Doe|1985-03-15|M|REF-1\n"), filename: "labs.txt", content_type: "text/plain")
    lab_import.save!

    assert lab_import.file.attached?
  end
end
