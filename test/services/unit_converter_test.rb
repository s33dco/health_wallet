require "test_helper"

class UnitConverterTest < ActiveSupport::TestCase
  test "returns the value unchanged when units match" do
    assert_equal 120, UnitConverter.convert(120, from: "mmHg", to: "mmHg")
  end

  test "converts Fahrenheit to Celsius" do
    assert_in_delta 37.0, UnitConverter.convert(98.6, from: "°F", to: "°C")
    assert_in_delta 0.0, UnitConverter.convert(32.0, from: "°F", to: "°C")
  end

  test "converts Celsius to Fahrenheit" do
    assert_in_delta 98.6, UnitConverter.convert(37.0, from: "°C", to: "°F")
    assert_in_delta 32.0, UnitConverter.convert(0.0, from: "°C", to: "°F")
  end

  test "returns nil for an unknown conversion" do
    assert_nil UnitConverter.convert(100, from: "mmHg", to: "kg")
    assert_nil UnitConverter.convert(300, from: "K", to: "°C")
  end
end
