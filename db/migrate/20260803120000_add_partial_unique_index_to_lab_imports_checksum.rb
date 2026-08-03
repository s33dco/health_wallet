class AddPartialUniqueIndexToLabImportsChecksum < ActiveRecord::Migration[8.1]
  def change
    # Enforces uniqueness of file_checksum only among rows currently processing (1) or
    # completed (2) — see the status enum mapping in LabImport. This closes the race where
    # two concurrent uploads of the same file both pass the in-app duplicate check while
    # each is still in flight: only one can win the transition into "processing" with a
    # given checksum, so the loser is caught and marked duplicate instead of double-importing.
    # Pending/failed/duplicate rows are excluded, so a genuine retry after a failure is unaffected.
    add_index :lab_imports, :file_checksum, unique: true, where: "status IN (1, 2)",
              name: "index_lab_imports_on_checksum_when_active"
  end
end
