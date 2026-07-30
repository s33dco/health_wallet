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
end
