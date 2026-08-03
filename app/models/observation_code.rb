# Reference data for the LOINC observation codes the importer understands. Unlike the
# clinical documents (Patient/Assessment/Observation), these are a controlled vocabulary:
# an incoming HL7 code must match one of these or the import is rejected.
#
# Each code optionally carries a plausible reference range (min_value..max_value) expressed
# in a canonical `unit`. Readings outside that range are flagged during import — a miniature
# version of a clinical interpretation engine.
class ObservationCode
  include Mongoid::Document

  field :code, type: String
  field :description, type: String
  field :unit, type: String
  field :min_value, type: Float
  field :max_value, type: Float

  index({ code: 1 }, { unique: true })

  validates :code, :description, presence: true
  validates :code, uniqueness: true
  # min_value/max_value/unit are deliberately optional: range-completeness is a data
  # assumption the seed defends, not a business rule enforced on every record.

  # Is `value` (given in `unit`) outside this code's reference range? Returns false when no
  # range is defined, or when the reading's unit can't be converted to the canonical unit —
  # we never flag on a guess we can't back.
  def out_of_range?(value, unit:)
    return false if min_value.nil? || max_value.nil?

    normalized = UnitConverter.convert(value, from: unit, to: self.unit)
    return false if normalized.nil?

    !(min_value..max_value).cover?(normalized)
  end
end
