require "test_helper"

class LabImportsControllerTest < ActionDispatch::IntegrationTest
  test "index lists imports with their filename and status" do
    lab_import = LabImport.create!(status: :completed)
    lab_import.file.attach(io: StringIO.new("data"), filename: "results.txt", content_type: "text/plain")
    lab_import.save!

    get lab_imports_url

    assert_response :success
    assert_match "results.txt", response.body
    assert_select "span.status-pill", text: "Completed"
  end

  test "index paginates, showing at most one page of imports" do
    per_page = LabImportsController::PER_PAGE
    (per_page + 3).times { LabImport.create!(status: :completed) }

    get lab_imports_url
    assert_response :success
    assert_select "tbody tr", count: per_page # first page is full
    assert_select "nav.pagination"

    get lab_imports_url(page: 2)
    assert_response :success
    assert_select "tbody tr", count: 3 # remainder on page 2
  end

  test "new renders the upload form" do
    get new_lab_import_url
    assert_response :success
    assert_select "input[type=file]"
  end

  test "uploading a file creates a LabImport and enqueues the import job" do
    file = fixture_file_upload("john_doe_hl7.txt", "text/plain")

    assert_enqueued_with(job: LabResultImportJob) do
      assert_difference "LabImport.count", 1 do
        post lab_imports_url, params: { lab_import: { file: file } }
      end
    end

    assert_redirected_to lab_import_url(LabImport.last)
    assert LabImport.last.file.attached?
  end

  test "uploading without a file re-renders the form with an error" do
    assert_no_difference "LabImport.count" do
      post lab_imports_url, params: { lab_import: {} }
    end

    assert_response :unprocessable_entity
    assert_select "input[type=file]"
  end

  test "show renders the status of an import" do
    lab_import = LabImport.create!(status: :completed)

    get lab_import_url(lab_import)

    assert_response :success
    assert_match(/Completed/, response.body)
  end
end
