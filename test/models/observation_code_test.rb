require "test_helper"

class ObservationCodeTest < ActiveSupport::TestCase
  test "requires code and description" do
    oc = ObservationCode.new

    assert_not oc.valid?
    assert_includes oc.errors.attribute_names, :code
    assert_includes oc.errors.attribute_names, :description
  end

  test "is valid with code and description" do
    oc = ObservationCode.new(code: "8480-6", description: "Blood Pressure (Systolic)")

    assert oc.valid?
  end

  test "enforces uniqueness on code" do
    ObservationCode.create!(code: "8480-6", description: "Blood Pressure (Systolic)")
    duplicate = ObservationCode.new(code: "8480-6", description: "Something else")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :code
  end

  test "unit and range are optional" do
    oc = ObservationCode.new(code: "8480-6", description: "Blood Pressure (Systolic)")

    assert oc.valid? # no unit/range set, still valid
  end

  # --- out_of_range? ---

  test "out_of_range? returns false when no range is defined" do
    oc = ObservationCode.create!(code: "8480-6", description: "Blood Pressure (Systolic)")

    assert_not oc.out_of_range?(999, unit: "mmHg")
  end

  test "out_of_range? flags values outside the range for the same unit" do
    oc = ObservationCode.create!(code: "8480-6", description: "Systolic", unit: "mmHg", min_value: 90, max_value: 180)

    assert oc.out_of_range?(250, unit: "mmHg")
    assert oc.out_of_range?(50, unit: "mmHg")
    assert_not oc.out_of_range?(120, unit: "mmHg")
  end

  test "out_of_range? treats the boundary values as in range" do
    oc = ObservationCode.create!(code: "8480-6", description: "Systolic", unit: "mmHg", min_value: 90, max_value: 180)

    assert_not oc.out_of_range?(90, unit: "mmHg")
    assert_not oc.out_of_range?(180, unit: "mmHg")
  end

  test "out_of_range? converts the reading's unit to the canonical unit before comparing" do
    # Range is Celsius; a normal Fahrenheit reading must not be falsely flagged.
    oc = ObservationCode.create!(code: "8310-5", description: "Body Temperature", unit: "°C", min_value: 36.0, max_value: 39.0)

    assert_not oc.out_of_range?(98.6, unit: "°F") # 98.6°F == 37°C, in range
    assert oc.out_of_range?(104.0, unit: "°F")    # 104°F == 40°C, above range
  end

  test "out_of_range? does not flag when the unit can't be converted" do
    oc = ObservationCode.create!(code: "8310-5", description: "Body Temperature", unit: "°C", min_value: 36.0, max_value: 39.0)

    assert_not oc.out_of_range?(500, unit: "K") # unknown conversion — never flag on a guess
  end
end
