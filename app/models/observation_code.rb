# Reference data for the LOINC observation codes the importer understands. Unlike the
# clinical documents (Patient/Assessment/Observation), these are a controlled vocabulary:
# an incoming HL7 code must match one of these or the import is rejected.
class ObservationCode
  include Mongoid::Document

  field :code, type: String
  field :description, type: String

  index({ code: 1 }, { unique: true })

  validates :code, :description, presence: true
  validates :code, uniqueness: true
end
