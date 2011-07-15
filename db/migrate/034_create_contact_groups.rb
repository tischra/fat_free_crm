class CreateContactGroups < ActiveRecord::Migration
  def self.up
    create_table :contact_groups do |t|
      t.references  :contact
      t.string  :email
      t.references  :crm_google_contact_sync
      t.timestamps
    end
  end

  def self.down
    drop_table :contact_groups
  end
end
