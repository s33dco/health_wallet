class AddSummaryToLabImports < ActiveRecord::Migration[8.1]
  def change
    # Serialized (JSON) record of what the import actually did — counts of records
    # created/matched, plus any flagged results. See LabImport#summary.
    add_column :lab_imports, :summary, :text
  end
end
