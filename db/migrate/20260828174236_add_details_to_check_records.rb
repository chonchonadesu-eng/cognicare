class AddDetailsToCheckRecords < ActiveRecord::Migration[7.1]
  def change
    # どの症状にチェックしたか（配列をJSONとして保存）
    add_column :check_records, :checked_ids, :text
    # 各タイプのスコア（ハッシュをJSON/テキストとして保存）
    add_column :check_records, :scores, :text
    # 最も特徴が一致したトップのタイプ名
    add_column :check_records, :top_type, :string
  end
end