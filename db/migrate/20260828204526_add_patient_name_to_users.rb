class AddPatientNameToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :patient_name, :string
  end
end
