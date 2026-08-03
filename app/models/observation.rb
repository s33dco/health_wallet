class Observation
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :code, type: String
  field :value, type: Float
  field :units, type: String

  embedded_in :assessment
  embeds_many :observation_histories

  # Record a new reading, preserving the prior one in the audit trail rather than silently
  # discarding it. `value`/`units` stay the current fast-access state (satisfying the spec's
  # literal update requirement); the history keeps every reading that came before.
  #
  # Wrapped in `atomically` so the new history entry and the current value/units land in a
  # single MongoDB write on the parent Assessment document — otherwise an interruption between
  # the two separate writes could leave the history showing a reading the current value doesn't.
  def record_reading!(value:, units:, source: "hl7_import")
    atomically do
      observation_histories.create!(value: value, units: units, source: source)
      update!(value: value, units: units)
    end
  end
end
