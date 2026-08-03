require "test_helper"

class ObservationHistoryTest < ActiveSupport::TestCase
  setup do
    patient = Patient.create!(name: "John Doe", dob: Date.new(1985, 3, 15), sex_at_birth: "Male")
    assessment = patient.assessments.create!(reference: "REF-2024-001", date: Date.current.to_s)
    @observation = assessment.observations.create!(code: "8480-6", name: "Blood Pressure (Systolic)")
  end

  test "is embedded in an observation and persists via the parent" do
    reading = @observation.observation_histories.create!(value: 120.0, units: "mmHg")

    assert reading.persisted?
    assert_equal @observation, reading.observation
  end

  test "defaults source to hl7_import" do
    reading = @observation.observation_histories.create!(value: 120.0, units: "mmHg")

    assert_equal "hl7_import", reading.source
  end
end
