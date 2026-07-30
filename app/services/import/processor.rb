module Import
  # Applies the spec's find-or-create rules for one parsed HL7 file. Kept as a plain object
  # (no ActiveJob, no controller) so the import logic is legible and unit-testable on its own;
  # the background job is just a thin wrapper around this.
  #
  #   Patient:     find by name + dob + sex_at_birth, else create
  #   Assessment:  find by reference within the patient, else create
  #   Observation: find by code within the assessment and update value/units, else create
  class Processor
    Result = Struct.new(
      :patients_created, :patients_matched,
      :assessments_created, :assessments_matched,
      :observations_created, :observations_updated,
      keyword_init: true
    )

    def initialize(content)
      @content = content
      @stats = Hash.new(0)
    end

    def call
      records = Hl7LabResultParser.parse(@content)
      records.each { |record| import_record(record) }
      # Read every counter through @stats (Hash.new(0)) so untouched ones report 0, not nil.
      Result.new(**Result.members.index_with { |key| @stats[key] })
    end

    private

    def import_record(record)
      patient = find_or_create_patient(record.patient)
      assessment = find_or_create_assessment(patient, record.patient.assessment_reference)
      record.observations.each { |obs| import_observation(assessment, obs) }
    end

    def find_or_create_patient(attrs)
      existing = Patient.where(name: attrs.name, dob: attrs.dob, sex_at_birth: attrs.sex_at_birth).first
      @stats[existing ? :patients_matched : :patients_created] += 1
      existing || Patient.create!(name: attrs.name, dob: attrs.dob, sex_at_birth: attrs.sex_at_birth)
    end

    def find_or_create_assessment(patient, reference)
      existing = patient.assessments.where(reference: reference).first
      @stats[existing ? :assessments_matched : :assessments_created] += 1
      # HL7 file carries no assessment date, so use the import date (zone-aware).
      existing || patient.assessments.create!(reference: reference, date: Date.current.to_s)
    end

    def import_observation(assessment, obs)
      observation = assessment.observations.where(code: obs.code).first
      if observation
        @stats[:observations_updated] += 1
      else
        @stats[:observations_created] += 1
        observation = assessment.observations.create!(code: obs.code, name: obs.name)
      end

      # Record the reading through the audit trail rather than overwriting in place, so a
      # corrected/re-run value keeps its history instead of silently replacing the old one.
      observation.record_reading!(value: obs.value, units: obs.units)
    end
  end
end
