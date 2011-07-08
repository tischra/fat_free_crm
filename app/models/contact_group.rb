class ContactGroup < ActiveRecord::Base
  belongs_to :crm_google_contact_sync
  belongs_to :contact
end
