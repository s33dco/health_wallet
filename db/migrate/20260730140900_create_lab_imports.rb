class CreateLabImports < ActiveRecord::Migration[8.1]
  def change
    create_table :lab_imports do |t|
      t.integer :status, null: false, default: 0 # 0 = pending, see enum mapping in LabImport
      t.text :error_message

      t.timestamps
    end
  end
end
