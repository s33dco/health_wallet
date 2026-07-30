# Base class for ActiveRecord-backed models. The clinical domain (Patient/Assessment/
# Observation/ObservationCode) lives in Mongoid; this exists for operational records like
# LabImport that are a better fit for a relational table with Active Storage attachments.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
