# Tracks the lifecycle of a single uploaded lab-result file. Deliberately ActiveRecord
# (SQLite) rather than Mongoid: this is an operational/audit record of an upload, not
# clinical domain data, and Active Storage's `has_one_attached` works cleanly against a
# relational id with no BSON friction.
class LabImport < ApplicationRecord
  has_one_attached :file

  # Explicit integer mapping (not the array shorthand) so inserting a new status later can't
  # silently shift the stored meaning of existing rows.
  enum :status, {
    pending:    0,
    processing: 1,
    completed:  2,
    failed:     3
  }, default: :pending

  # Lifecycle transitions. The enum's bang methods (`processing!`, `completed!`) set the
  # status and persist in one call; `mark_failed!` also records why.
  def mark_processing! = processing!
  def mark_completed!  = completed!

  def mark_failed!(message)
    update!(status: :failed, error_message: message)
  end
end
