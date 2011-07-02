class CreateCrmGoogleContactSyncs < ActiveRecord::Migration
  def self.up
    create_table :crm_google_contact_syncs do |t|
      t.string :email
      t.string :lead_group
      t.string :contact_group

      t.timestamps
    end
  end

  def self.down
    drop_table :crm_google_contact_syncs
  end
end
