class AddFileChecksumToLabImports < ActiveRecord::Migration[8.1]
  def change
    add_column :lab_imports, :file_checksum, :string
    add_index :lab_imports, :file_checksum
  end
end
