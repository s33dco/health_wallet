# One recorded reading for an Observation, preserved so a corrected or re-run lab result
# never silently discards the prior value. The Observation keeps `value`/`units` as the
# fast-access "current" state; this is the audit trail behind it.
class ObservationHistory
  include Mongoid::Document
  include Mongoid::Timestamps

  field :value, type: Float
  field :units, type: String
  field :source, type: String, default: "hl7_import"

  embedded_in :observation
end
