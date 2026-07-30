require "test_helper"

class LabImportsControllerTest < ActionDispatch::IntegrationTest
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
