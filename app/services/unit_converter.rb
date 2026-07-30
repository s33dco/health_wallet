# Converts a measurement between units. Intentionally tiny: only the conversions the lab
# data actually needs (temperature °F <-> °C) are defined. Identical units pass through
# unchanged; an unknown conversion returns nil so callers can decline to act rather than
# guess (e.g. ObservationCode#out_of_range? treats nil as "can't compare, don't flag").
class UnitConverter
  CONVERSIONS = {
    [ "°F", "°C" ] => ->(v) { (v - 32) * 5.0 / 9.0 },
    [ "°C", "°F" ] => ->(v) { (v * 9.0 / 5.0) + 32 }
  }.freeze

  # Returns `value` expressed in `to`, or nil if the conversion isn't known.
  def self.convert(value, from:, to:)
    return value if from == to

    conversion = CONVERSIONS[[ from, to ]]
    conversion&.call(value)
  end
end
