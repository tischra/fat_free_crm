class CreateContactGroups < ActiveRecord::Migration
  def self.up
    create_table :contact_groups do |t|
      t.boolean :status, :default => false
      t.references  :contact
      t.references  :crm_google_contact_sync
      t.timestamps
    end
  end

  def self.down
    drop_table :contact_groups
  end
end
