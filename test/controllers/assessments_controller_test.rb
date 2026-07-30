require "test_helper"

class AssessmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @patient = Patient.create!(
      name: "Test Patient",
      dob: Date.new(1990, 5, 15),
      sex_at_birth: "Male"
    )
    @assessment = @patient.assessments.create!(
      date: "2025-01-07",
      reference: "ASM-TEST-001"
    )
  end

  test "should show assessment" do
    get assessment_url(@assessment)
    assert_response :success
  end

  test "shows assessment reference" do
    get assessment_url(@assessment)
    assert_match @assessment.reference, response.body
  end

  test "shows a reading-history disclosure for an observation with recorded history" do
    observation = @assessment.observations.create!(code: "8480-6", name: "Blood Pressure (Systolic)")
    observation.record_reading!(value: 120.0, units: "mmHg")
    observation.record_reading!(value: 115.0, units: "mmHg") # corrected

    get assessment_url(@assessment)

    assert_response :success
    assert_select "details.obs-history summary.obs-value--changed"
    assert_select "span.obs-history-badge", text: "2"
    # Both readings appear in the expandable panel.
    assert_select ".obs-history-panel .obs-history-value", text: /120\.0 mmHg/
    assert_select ".obs-history-panel .obs-history-value", text: /115\.0 mmHg/
  end

  test "shows a plain value with no disclosure when an observation has no history" do
    @assessment.observations.create!(code: "8480-6", name: "Blood Pressure (Systolic)", value: 120.0, units: "mmHg")

    get assessment_url(@assessment)

    assert_response :success
    assert_select "details.obs-history", count: 0
  end
end
