require "test_helper"

module Import
  class ProcessorTest < ActiveSupport::TestCase
    setup do
      ObservationCode.create!(code: "8480-6", description: "Blood Pressure (Systolic)")
      ObservationCode.create!(code: "8462-4", description: "Blood Pressure (Diastolic)")
    end

    test "creates a new Patient, Assessment, and Observation on first import" do
      content = "John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|mmHg\n"

      result = Import::Processor.new(content).call

      assert_equal 1, result.patients_created
      assert_equal 1, result.assessments_created
      assert_equal 1, result.observations_created
      assert_equal 1, Patient.count
      patient = Patient.first
      assert_equal "John Doe", patient.name
      assert_equal "Male", patient.sex_at_birth
      assert_equal 1, patient.assessments.count
      observation = patient.assessments.first.observations.first
      assert_equal "Blood Pressure (Systolic)", observation.name
      assert_in_delta 120.0, observation.value
      assert_equal "mmHg", observation.units
    end

    test "is idempotent: re-importing the same file matches instead of duplicating" do
      content = "John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|mmHg\n"

      Import::Processor.new(content).call
      result = Import::Processor.new(content).call # same file again

      assert_equal 0, result.patients_created
      assert_equal 1, result.patients_matched
      assert_equal 1, result.assessments_matched
      assert_equal 1, result.observations_updated
      assert_equal 1, Patient.count
      assert_equal 1, Patient.first.assessments.count
      assert_equal 1, Patient.first.assessments.first.observations.count
    end

    test "updates an existing observation's value and units when re-imported" do
      Import::Processor.new("John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|mmHg\n").call
      Import::Processor.new("John Doe|1985-03-15|M|REF-2024-001\n8480-6|125|mmHg\n").call

      observation = Patient.first.assessments.first.observations.first
      assert_in_delta 125.0, observation.value
    end

    test "adds a new observation to an existing assessment" do
      Import::Processor.new("John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|mmHg\n").call
      result = Import::Processor.new("John Doe|1985-03-15|M|REF-2024-001\n8462-4|80|mmHg\n").call

      assert_equal 1, result.observations_created
      assert_equal 2, Patient.first.assessments.first.observations.count
    end

    test "creates separate patients and assessments for multiple records" do
      content = <<~HL7
        John Doe|1985-03-15|M|REF-2024-003
        8480-6|120|mmHg
        Jane Smith|1990-07-22|F|REF-2024-004
        8462-4|78|mmHg
      HL7

      result = Import::Processor.new(content).call

      assert_equal 2, result.patients_created
      assert_equal 2, result.assessments_created
      assert_equal 2, Patient.count
    end

    test "a different reference for the same patient creates a second assessment" do
      Import::Processor.new("John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|mmHg\n").call
      result = Import::Processor.new("John Doe|1985-03-15|M|REF-2024-002\n8480-6|118|mmHg\n").call

      assert_equal 1, result.patients_matched
      assert_equal 1, result.assessments_created
      assert_equal 1, Patient.count
      assert_equal 2, Patient.first.assessments.count
    end
  end
end
