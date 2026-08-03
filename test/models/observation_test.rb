require "test_helper"

class ObservationTest < ActiveSupport::TestCase
  test "can create an observation" do
    patient = Patient.create!(name: "Test Patient", dob: Date.today, sex_at_birth: "Male")
    assessment = patient.assessments.create!(date: "2025-01-07", reference: "ASM-TEST-001")

    observation = assessment.observations.create!(
      name: "Heart Rate",
      code: "8867-4",
      value: 72.0,
      units: "bpm"
    )

    assert_equal "Heart Rate", observation.name
    assert_equal 72.0, observation.value
  end

  test "record_reading! sets the current value and units" do
    observation = build_observation

    observation.record_reading!(value: 120.0, units: "mmHg")

    assert_equal 120.0, observation.value
    assert_equal "mmHg", observation.units
  end

  test "record_reading! appends to the audit trail rather than replacing it" do
    observation = build_observation

    observation.record_reading!(value: 120.0, units: "mmHg")
    observation.record_reading!(value: 125.0, units: "mmHg")

    assert_equal 2, observation.observation_histories.count
    assert_equal [ 120.0, 125.0 ], observation.observation_histories.order_by(created_at: :asc).map(&:value)
  end

  test "record_reading! defaults the reading source to hl7_import" do
    observation = build_observation

    observation.record_reading!(value: 120.0, units: "mmHg")

    assert_equal "hl7_import", observation.observation_histories.first.source
  end

  private

  def build_observation
    patient = Patient.create!(name: "Test Patient", dob: Date.new(1990, 1, 1), sex_at_birth: "Male")
    assessment = patient.assessments.create!(reference: "ASM-TEST-001", date: Date.current.to_s)
    assessment.observations.create!(code: "8480-6", name: "Blood Pressure (Systolic)")
  end
end
