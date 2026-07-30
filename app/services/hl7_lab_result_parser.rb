# Parses the simplified HL7 lab-result format into plain value objects. Deliberately
# framework-agnostic: it does no database writes, so it can be unit-tested in isolation.
#
# Format (pipe-delimited):
#   patient_name|patient_dob|patient_sex_at_birth|assessment_reference   (4 fields, header)
#   code|result|units                                                    (3 fields, observation)
#   code|result|units
#
# A 4-field line always starts a new patient/assessment block; the 3-field lines that
# follow are that block's observations (matches the Multiple_Patients example in the spec).
class Hl7LabResultParser
  ParseError = Class.new(StandardError)

  Record           = Struct.new(:patient, :observations, keyword_init: true)
  PatientAttrs     = Struct.new(:name, :dob, :sex_at_birth, :assessment_reference, keyword_init: true)
  ObservationAttrs = Struct.new(:code, :name, :value, :units, keyword_init: true)

  # HL7 files carry the single-letter code; the domain stores the full word.
  SEX_MAP = { "M" => "Male", "F" => "Female" }.freeze

  def self.parse(content) = new(content).parse

  def initialize(content)
    # Active Storage's `download` hands back an ASCII-8BIT (binary) string. Units such as
    # "°F" are valid UTF-8 bytes but, left tagged as binary, blow up when Mongoid serializes
    # them to BSON (which is UTF-8). Reinterpret as UTF-8 and fail loud if the bytes aren't.
    text = content.to_s.dup.force_encoding(Encoding::UTF_8)
    raise ParseError, "File is not valid UTF-8 text" unless text.valid_encoding?

    @lines = text.each_line.map(&:strip).reject(&:empty?)
  end

  def parse
    records = []
    current = nil

    @lines.each_with_index do |line, idx|
      fields = line.split("|")

      case fields.length
      when 4
        current = Record.new(patient: build_patient(fields, idx), observations: [])
        records << current
      when 3
        raise ParseError, "Observation on line #{idx + 1} has no preceding patient header" unless current

        current.observations << build_observation(fields, idx)
      else
        raise ParseError, "Line #{idx + 1} has an unexpected number of fields (#{fields.length}): #{line.inspect}"
      end
    end

    records
  end

  private

  def build_patient(fields, idx)
    name, dob, sex, reference = fields.map(&:strip)
    mapped_sex = SEX_MAP[sex]
    raise ParseError, "Unknown sex_at_birth code #{sex.inspect} on line #{idx + 1}" unless mapped_sex

    PatientAttrs.new(name: name, dob: Date.parse(dob), sex_at_birth: mapped_sex, assessment_reference: reference)
  rescue Date::Error
    raise ParseError, "Invalid date of birth #{fields[1].inspect} on line #{idx + 1}"
  end

  def build_observation(fields, idx)
    code, result, units = fields.map(&:strip)
    # `where(...).first` rather than `find_by`: Mongoid's find_by raises DocumentNotFound,
    # but here a missing code should surface as our own ParseError.
    observation_code = ObservationCode.where(code: code).first
    raise ParseError, "Unknown observation code #{code.inspect} on line #{idx + 1}" unless observation_code

    ObservationAttrs.new(code: code, name: observation_code.description, value: result.to_f, units: units)
  end
end
