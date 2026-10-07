class AddTotalCheckedAndLangToCheckRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :check_records, :total_checked, :integer, default: 0, null: false
    add_column :check_records, :lang, :string, default: 'ja', null: false
  end
end