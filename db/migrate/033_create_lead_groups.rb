class CreateLeadGroups < ActiveRecord::Migration
  def self.up
    create_table :lead_groups do |t|
      t.boolean :status ,:default => false
      t.references  :lead
      t.references  :crm_google_contact_sync
      t.timestamps
    end
  end

  def self.down
    drop_table :lead_groups
  end
end
