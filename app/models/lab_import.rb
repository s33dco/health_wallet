# Tracks the lifecycle of a single uploaded lab-result file. Deliberately ActiveRecord
# (SQLite) rather than Mongoid: this is an operational/audit record of an upload, not
# clinical domain data, and Active Storage's `has_one_attached` works cleanly against a
# relational id with no BSON friction.
class LabImport < ApplicationRecord
  has_one_attached :file

  # summary is a plain Ruby hash of import stats; a text column needs explicit (de)serialization.
  serialize :summary, coder: JSON

  # Explicit integer mapping (not the array shorthand) so inserting a new status later can't
  # silently shift the stored meaning of existing rows.
  enum :status, {
    pending:    0,
    processing: 1,
    completed:  2,
    failed:     3,
    duplicate:  4
  }, default: :pending

  # Lifecycle transitions. `mark_processing!`/`mark_duplicate!` use the enum's bang methods;
  # the others also persist a second attribute (the summary or the error) in the same write.
  def mark_processing! = processing!
  def mark_duplicate!  = duplicate!

  def mark_completed!(summary = nil)
    update!(status: :completed, summary: summary)
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message)
  end

  # A previously completed import of the same file (by checksum). Only completed imports
  # count, so a prior failure or duplicate never blocks a genuine retry.
  def duplicate_of
    return nil if file_checksum.blank?

    LabImport.completed.where(file_checksum: file_checksum).where.not(id: id).first
  end
end
