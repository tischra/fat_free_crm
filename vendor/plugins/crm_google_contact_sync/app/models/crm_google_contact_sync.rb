require 'gdata'
class CrmGoogleContactSync < ActiveRecord::Base
  has_many :lead_groups, :dependent => :destroy
  has_many :contact_groups, :dependent => :destroy
  def CrmGoogleContactSync.sync
    google_contact_syncs = CrmGoogleContactSync.find(:all)
    google_contact_syncs.each do |google_contact_sync|
      contacts = Contact.find(:all, :conditions =>["user_id = ?", google_contact_sync.user_id])
      contacts.each do |contact|
        contact_group = ContactGroup.find(:first, :conditions => ["contact_id = ?", contact.id])
        puts 'contacts'
        puts contact_group
        puts 'co'
        if contact_group == nil
          contact_group = ContactGroup.new
          contact_group.contact = contact
          contact_group.crm_google_contact_sync = google_contact_sync
          contact_group.save
        end
      end
      leads = Lead.find(:all, :conditions => ["user_id = ?", google_contact_sync.user_id])
      leads.each do |lead|
        lead_group = LeadGroup.find(:first , :conditions => ["lead_id = ?", lead.id])
        if lead_group == nil
          lead_group = LeadGroup.new
          lead_group.lead = lead
          lead_group.crm_google_contact_sync = google_contact_sync
          lead_group.save
        end
      end
          client = GData::Client::DocList.new

   # client.authsub_token = Session[:token] if Session[:token]
      if google_contact_sync.token != nil
        client.authsub_token =  google_contact_sync.token
        puts 'token'
        puts google_contact_sync.token
        contact_groups = ContactGroup.find(:all, :conditions =>["crm_google_contact_sync_id = ? AND status = ?", google_contact_sync.id, false])
        puts 'contact_groups'
        puts contact_groups
        contact_groups.each do |contact_group|
        puts'bagia'
          entry_str = <<-EOF
                       <entry xmlns="http://www.w3.org/2005/Atom"
                  xmlns:gContact='http://schemas.google.com/contact/2008'
                              xmlns:contact="http://schemas.google.com/contact/2008"
                              xmlns:gd="http://schemas.google.com/g/2005">

                         <category term='http://schemas.google.com/contact/2008#contact'
                                   scheme='http://schemas.google.com/g/2005#kind'/>
                  <title>#{contact_group.contact.first_name} #{contact_group.contact.last_name}</title>
                  <content>Belong to Fat Free</content>
                  <gd:name>
                    <gd:fullName>#{contact_group.contact.first_name} #{contact_group.contact.last_name}</gd:fullName>
                  </gd:name>
                  <gd:email primary='true' rel='http://schemas.google.com/g/2005#home' address='#{contact_group.contact.email}'/>
               <gContact:groupMembershipInfo deleted="false" href="#{contact_group.crm_google_contact_sync.contact_group_id}"/>
 </entry>
          EOF
          client.post('https://www.google.com/m8/feeds/contacts/default/full', entry_str).to_xml
          contact_group.update_attribute("status", true)
        end

        lead_groups = LeadGroup.find(:all, :conditions =>["crm_google_contact_sync_id = ? AND status = ?", google_contact_sync.id, false])
        lead_groups.each do |lead_group|

          entry_str = <<-EOF
                       <entry xmlns="http://www.w3.org/2005/Atom"
                  xmlns:gContact='http://schemas.google.com/contact/2008'
                              xmlns:contact="http://schemas.google.com/contact/2008"
                              xmlns:gd="http://schemas.google.com/g/2005">

                         <category term='http://schemas.google.com/contact/2008#contact'
                                   scheme='http://schemas.google.com/g/2005#kind'/>
                  <title>#{lead_group.lead.first_name} #{lead_group.lead.last_name}</title>
                  <content>Belong to Fat Free</content>
                  <gd:name>
                    <gd:fullName>#{lead_group.lead.first_name} #{lead_group.lead.last_name}</gd:fullName>
                  </gd:name>
                  <gd:email primary='true' rel='http://schemas.google.com/g/2005#home' address='#{lead_group.lead.email}'/>
               <gContact:groupMembershipInfo deleted="false" href="#{lead_group.crm_google_contact_sync.lead_group_id}"/>
 </entry>
          EOF
          client.post('https://www.google.com/m8/feeds/contacts/default/full', entry_str).to_xml
          lead_group.update_attribute("status", true)
        
        end
      end
    end

  end
end
