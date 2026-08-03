require "test_helper"

class Hl7LabResultParserTest < ActiveSupport::TestCase
  setup do
    ObservationCode.create!(code: "8480-6", description: "Blood Pressure (Systolic)")
    ObservationCode.create!(code: "8462-4", description: "Blood Pressure (Diastolic)")
  end

  test "parses a single patient with multiple observations" do
    content = <<~HL7
      John Doe|1985-03-15|M|REF-2024-001
      8480-6|120|mmHg
      8462-4|80|mmHg
    HL7

    records = Hl7LabResultParser.parse(content)

    assert_equal 1, records.length
    patient = records.first.patient
    assert_equal "John Doe", patient.name
    assert_equal Date.new(1985, 3, 15), patient.dob
    assert_equal "Male", patient.sex_at_birth # M mapped to the full word
    assert_equal "REF-2024-001", patient.assessment_reference
    assert_equal 2, records.first.observations.length
    obs = records.first.observations.first
    assert_equal "8480-6", obs.code
    assert_equal "Blood Pressure (Systolic)", obs.name # pulled from ObservationCode
    assert_in_delta 120.0, obs.value
    assert_equal "mmHg", obs.units
  end

  test "parses multiple patients in one file, resetting context on each header" do
    content = <<~HL7
      John Doe|1985-03-15|M|REF-2024-003
      8480-6|120|mmHg
      Jane Smith|1990-07-22|F|REF-2024-004
      8462-4|78|mmHg
    HL7

    records = Hl7LabResultParser.parse(content)

    assert_equal 2, records.length
    assert_equal "John Doe", records[0].patient.name
    assert_equal 1, records[0].observations.length
    assert_equal "Jane Smith", records[1].patient.name
    assert_equal "Female", records[1].patient.sex_at_birth
    assert_equal 1, records[1].observations.length
  end

  test "ignores blank lines and surrounding whitespace" do
    content = "  John Doe|1985-03-15|M|REF-2024-001  \n\n   8480-6|120|mmHg  \n"

    records = Hl7LabResultParser.parse(content)

    assert_equal 1, records.length
    assert_equal "John Doe", records.first.patient.name
    assert_equal 1, records.first.observations.length
  end

  test "handles binary (ASCII-8BIT) input with non-ASCII units, as Active Storage downloads it" do
    ObservationCode.create!(code: "8310-5", description: "Body Temperature")
    # Bytes as they arrive from file.download: valid UTF-8 for "°F" but tagged ASCII-8BIT.
    content = "John Doe|1985-03-15|M|REF-2024-001\n8310-5|98.6|°F\n".dup.force_encoding(Encoding::ASCII_8BIT)

    records = Hl7LabResultParser.parse(content)

    units = records.first.observations.first.units
    assert_equal "°F", units
    assert_equal Encoding::UTF_8, units.encoding
  end

  test "raises on an observation code not in the known list" do
    content = <<~HL7
      John Doe|1985-03-15|M|REF-2024-001
      9999-9|120|mmHg
    HL7

    error = assert_raises(Hl7LabResultParser::ParseError) { Hl7LabResultParser.parse(content) }
    assert_match(/Unknown observation code/, error.message)
  end

  test "raises on an observation line with no preceding patient header" do
    content = "8480-6|120|mmHg\n"

    error = assert_raises(Hl7LabResultParser::ParseError) { Hl7LabResultParser.parse(content) }
    assert_match(/no preceding patient header/, error.message)
  end

  test "raises on an unknown sex_at_birth code" do
    content = "John Doe|1985-03-15|X|REF-2024-001\n"

    error = assert_raises(Hl7LabResultParser::ParseError) { Hl7LabResultParser.parse(content) }
    assert_match(/Unknown sex_at_birth/, error.message)
  end

  test "raises on an invalid date of birth" do
    content = "John Doe|not-a-date|M|REF-2024-001\n"

    error = assert_raises(Hl7LabResultParser::ParseError) { Hl7LabResultParser.parse(content) }
    assert_match(/Invalid date of birth/, error.message)
  end

  test "raises on a malformed line with the wrong number of fields" do
    content = "John Doe|1985-03-15|M\n" # missing assessment_reference

    assert_raises(Hl7LabResultParser::ParseError) { Hl7LabResultParser.parse(content) }
  end

  test "raises on a non-numeric observation result instead of silently coercing to 0.0" do
    content = "John Doe|1985-03-15|M|REF-2024-001\n8480-6|ERR|mmHg\n"

    error = assert_raises(Hl7LabResultParser::ParseError) { Hl7LabResultParser.parse(content) }
    assert_match(/Invalid observation result/, error.message)
  end

  test "raises on a blank observation result" do
    content = "John Doe|1985-03-15|M|REF-2024-001\n8480-6||mmHg\n"

    assert_raises(Hl7LabResultParser::ParseError) { Hl7LabResultParser.parse(content) }
  end
end
