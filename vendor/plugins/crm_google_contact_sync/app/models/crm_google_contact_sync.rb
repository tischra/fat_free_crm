require 'gdata'
class CrmGoogleContactSync < ActiveRecord::Base
  has_many :lead_groups, :dependent => :destroy
  has_many :contact_groups, :dependent => :destroy

  def CrmGoogleContactSync.sync_contact
    google_contact_syncs = CrmGoogleContactSync.find(:all)
    google_contact_syncs.each do |google_contact_sync|
      client = GData::Client::Contacts.new
      contact_group = ContactGroup.find(:first, :conditions =>["crm_google_contact_sync_id = ?", google_contact_sync.id])
      if contact_group == nil
        contacts = Contact.find(:all, :conditions =>["user_id = ?", google_contact_sync.user_id])
        contacts.each do |contact|

          contact_group = ContactGroup.new
          contact_group.contact = contact
          contact_group.crm_google_contact_sync = google_contact_sync
          contact_group.email = contact.email
          contact_group.save
     
        end
        if google_contact_sync.token != nil
          client.authsub_token =  google_contact_sync.token
          contact_groups = ContactGroup.find(:all, :conditions =>["crm_google_contact_sync_id = ?", google_contact_sync.id])
          contact_groups.each do |contact_group|
            add_phone_address = ''
            if contact_group.contact.mobile != nil and contact_group.contact.mobile != ''
              add_phone_address = <<-EOF
  <gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>#{contact_group.contact.mobile}</gd:phoneNumber>
              EOF
            end
            if Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',contact_group.contact.id ]) != nil and  Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',contact_group.contact.id ]) != ''
              add_phone_address = <<-EOF
#{add_phone_address}<gd:postalAddress rel='http://schemas.google.com/g/2005#home'>#{Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',contact_group.contact.id ]).full_address}</gd:postalAddress>
              EOF
            end
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
                  #{add_phone_address}
               <gContact:groupMembershipInfo deleted="false" href="#{contact_group.crm_google_contact_sync.contact_group_id}"/>
 </entry>
            EOF

            client.post('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000', entry_str).to_xml
        
          end
        end
      else
        #delete contact
        delete_contact_groups =  ContactGroup.find(:all, :conditions =>["crm_google_contact_sync_id = ?", google_contact_sync.id])
        delete_contact_groups.each do |delete_contact_group|
          contact = Contact.find(:first, :conditions =>["user_id = ? and id = ?", google_contact_sync.user_id, delete_contact_group.contact_id])
          if contact
            puts 'aaaa'
            puts contact.email
            puts '2222'
            check = false
            client.authsub_token =  google_contact_sync.token
            feed = client.get('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000').to_xml
            puts feed
            feed.elements.each('entry') do |entry|
              gcontact_group_member_ship_info = ''
              gcontact_group_member_ship_info_second = ''
              entry.elements.each("gContact:groupMembershipInfo") do |member|
              
                if gcontact_group_member_ship_info.length < member.attributes["href"].length
                  gcontact_group_member_ship_info = member.attributes["href"]
                else
                  gcontact_group_member_ship_info_second = member.attributes["href"]
                end
              end
              if entry.elements["gd:email"]
                email = entry.elements["gd:email"].attributes['address']
                if email == contact.email and (gcontact_group_member_ship_info == google_contact_sync.contact_group_id or gcontact_group_member_ship_info_second == google_contact_sync.contact_group_id)
                  check = true
                end
              end
            end
            if check == false
              puts 'delete contact'
              contact.destroy
              delete_contact_group.delete
            end
          else
            puts 'bbbb'
            check = false
            delete_entry = nil
            client.authsub_token =  google_contact_sync.token
            feed = client.get('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000').to_xml
            feed.elements.each('entry') do |entry|
              email = entry.elements["gd:email"].attributes['address']
              if email == delete_contact_group.email
                check = true
                delete_entry = entry
              end
            end
            if check == true
              edit_uri = delete_entry.elements["link[@rel='edit']"].attributes['href']
              client.headers['If-Match'] = delete_entry.attribute('etag').value  # make sure we don't nuke another client's updates
              puts 'delete google'
              edit_uri = edit_uri.gsub("%40", '@')
              client.delete(edit_uri)
              delete_contact_group.delete
            end
          end
        end
        contacts = Contact.find(:all, :conditions =>["user_id = ?", google_contact_sync.user_id])
        contacts.each do |contact|
          contact_group = ContactGroup.find(:first, :conditions => ["contact_id = ?", contact.id])
          if contact_group == nil
            contact_group = ContactGroup.new
            contact_group.contact = contact
            contact_group.crm_google_contact_sync = google_contact_sync
            contact_group.email = contact.email
            contact_group.save
            if google_contact_sync.token != nil
              check = false
              entry_update = nil
              client.authsub_token =  google_contact_sync.token
              feed = client.get('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000').to_xml
              feed.elements.each('entry') do |entry|
                gcontact_group_member_ship_info = ''
                gcontact_group_member_ship_info_second = ''
                entry.elements.each("gContact:groupMembershipInfo") do |member|
                  
                  if gcontact_group_member_ship_info.length < member.attributes["href"].length
                    gcontact_group_member_ship_info = member.attributes["href"]
                  else
                    gcontact_group_member_ship_info_second =  member.attributes["href"]
                  end
                end
                email = entry.elements["gd:email"].attributes['address']
                if email == contact.email and (gcontact_group_member_ship_info == google_contact_sync.contact_group_id or gcontact_group_member_ship_info_second == google_contact_sync.contact_group_id)
                  check = true
                  entry_update = entry
                end
              end
              if check == false
                add_phone_address = ''
                if contact.mobile != nil and contact.mobile != ''
                  add_phone_address = <<-EOF
  <gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>#{contact.mobile}</gd:phoneNumber>
                  EOF
                end
                if Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]) != nil and  Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]) != ''
                  add_phone_address = <<-EOF
#{add_phone_address}<gd:postalAddress rel='http://schemas.google.com/g/2005#home'>#{Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]).full_address}</gd:postalAddress>
                  EOF
                end
                entry_str = <<-EOF
                       <entry xmlns="http://www.w3.org/2005/Atom"
                  xmlns:gContact='http://schemas.google.com/contact/2008'
                              xmlns:contact="http://schemas.google.com/contact/2008"
                              xmlns:gd="http://schemas.google.com/g/2005">

                         <category term='http://schemas.google.com/contact/2008#contact'
                                   scheme='http://schemas.google.com/g/2005#kind'/>
                  <title>#{contact.first_name} #{contact.last_name}</title>
                  <content>Belong to Fat Free</content>
                  <gd:name>
                    <gd:fullName>#{contact.first_name} #{contact.last_name}</gd:fullName>
                  </gd:name>
                  <gd:email primary='true' rel='http://schemas.google.com/g/2005#home' address='#{contact.email}'/>
                  #{add_phone_address}
               <gContact:groupMembershipInfo deleted="false" href="#{google_contact_sync.contact_group_id}"/>
 </entry>
                EOF

                client.post('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000', entry_str).to_xml
                

              else
                if contact.updated_status == true
                  entry_update.elements['title'].text = contact.first_name + '' + contact.last_name
                  entry_update.elements['gd:fullName'].text = contact.first_name + '' + contact.last_name
                  if contact.mobile != nil and contact.mobile != ''
                    entry_update.elements['gd:phoneNumber'].text = contact.mobile
                  end
                  if Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]) != nil and  Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]) != ''
                    entry_update.elements['gd:postalAddress'].text = Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]).full_address
                  end

                  edit_uri = entry_update.elements["link[@rel='edit']"].attributes['href']
                  response = client.put(edit_uri, entry_update.to_s)
                end
              end
            end
          end
        end
        if google_contact_sync.token != nil
          puts 'a'
          client.authsub_token =  google_contact_sync.token
          feed = client.get('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000').to_xml
          puts feed
          feed.elements.each('entry') do |entry|
   
            gcontact_group_member_ship_info = ''
            gcontact_group_member_ship_info_second = ''
            entry.elements.each("gContact:groupMembershipInfo") do |member|
              
              if gcontact_group_member_ship_info.length < member.attributes["href"].length
                gcontact_group_member_ship_info = member.attributes["href"]
              else
                gcontact_group_member_ship_info_second = member.attributes["href"]
              end
            end
            puts '.....................'
            puts gcontact_group_member_ship_info
            puts gcontact_group_member_ship_info_second
            puts google_contact_sync.contact_group_id
            puts entry.elements['gd:email'].attributes["address"]
            puts '................'
            if gcontact_group_member_ship_info and (gcontact_group_member_ship_info == google_contact_sync.contact_group_id or gcontact_group_member_ship_info_second == google_contact_sync.contact_group_id)
              puts 'abc contact'
              puts entry.elements['gd:email'].attributes["address"]

              contact = Contact.find(:first, :conditions => ["user_id = ? AND email = ?",google_contact_sync.user_id,  entry.elements['gd:email'].attributes["address"]])
              puts contact
              puts 'cotact....'
              if contact == nil
                puts 'ba gia do do'
                contact = Contact.new
                contact.first_name = entry.elements['title'].text
                contact.last_name = '-'
                contact.user_id = google_contact_sync.user_id
                contact.email = entry.elements['gd:email'].attributes["address"]
                if entry.elements['gd:phoneNumber']
                  contact.mobile =  entry.elements['gd:phoneNumber'].text
                end
                contact.save
                puts contact.errors.full_messages
                if entry.elements['gd:postalAddress']
                  address = Address.new
                  address.addressable_id = contact.id
                  address.address_type = "Business"
                  address.full_address = entry.elements['gd:postalAddress'].text
                  address.save
                end
                contact_group = ContactGroup.new
                contact_group.contact = contact
                contact_group.crm_google_contact_sync = google_contact_sync
                contact_group.email = contact.email
                contact_group.save

              else
                if contact.updated_status == true

                  entry.elements['title'].text = contact.first_name + ' ' + contact.last_name
                  if contact.mobile != nil and contact.mobile != ''
                    if entry.elements['gd:phoneNumber'] == nil
                      entry.add_element("<gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>" + contact.mobile + '</gd:phoneNumber>')
                    else
                      entry.elements['gd:phoneNumber'].text = contact.mobile
                    end
                  end
                  if Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]) != nil and  Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]).full_address != ''
                    if entry.elements['gd:postalAddress'] == nil
                      entry.add_element("<gd:postalAddress rel='http://schemas.google.com/g/2005#home'>" +  Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]).full_address + "</gd:postalAddress>")
                    else

                      entry.elements['gd:postalAddress'].text = Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]).full_address
                  
                    end
                  end
                  contact.update_attribute("updated_status" ,false)
                  puts  entry.elements['gd:postalAddress'].text
                  edit_uri = entry.elements["link[@rel='edit']"].attributes['href']
                  puts edit_uri
                  edit_uri = edit_uri.gsub("%40", '@')
                  client.headers['If-Match'] = entry.attribute('etag').value
                  entry.attribute('etag').remove()
                  entry.add_namespace('http://www.w3.org/2005/Atom')
                  entry.add_namespace('gd','http://schemas.google.com/g/2005')
                  entry.add_namespace('gContact', 'http://schemas.google.com/contact/2008')
                  entry.add_namespace('contact', 'http://schemas.google.com/contact/2008')
                  client.put(edit_uri, entry.to_s)
                  # response = client.put(edit_uri, "<entry xmlns='http://www.w3.org/2005/Atom'
                  #xmlns:gContact='http://schemas.google.com/contact/2008'
                  #           xmlns:contact='http://schemas.google.com/contact/2008'
                  #          xmlns:gd='http://schemas.google.com/g/2005'><id>http://www.google.com/m8/feeds/contacts/nguyenhuynhutsimple%40gmail.com/base/23ded2cb881ad373</id><updated>2011-07-14T09:46:09.671Z</updated><app:edited xmlns:app='http://www.w3.org/2007/app'>2011-07-14T09:46:09.671Z</app:edited><category term='http://schemas.google.com/contact/2008#contact' scheme='http://schemas.google.com/g/2005#kind'/><title>ba gia update a</title><content>Belong to Fat Free</content><link href='https://www.google.com/m8/feeds/photos/media/nguyenhuynhutsimple%40gmail.com/23ded2cb881ad373' gd:etag='&quot;ehlvYWI-bCp7ImBfH3QbSwxRH308fzgvKDY.&quot;' rel='http://schemas.google.com/contacts/2008/rel#photo' type='image/*'/><link href='https://www.google.com/m8/feeds/contacts/nguyenhuynhutsimple%40gmail.com/full/23ded2cb881ad373' rel='self' type='application/atom+xml'/><link href='https://www.google.com/m8/feeds/contacts/nguyenhuynhutsimple%40gmail.com/full/23ded2cb881ad373' rel='edit' type='application/atom+xml'/><gd:email address='huyenanh@gmail.com' rel='http://schemas.google.com/g/2005#home' primary='true'/><gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>update</gd:phoneNumber><gd:postalAddress rel='http://schemas.google.com/g/2005#home'>aa t</gd:postalAddress><gContact:groupMembershipInfo href='http://www.google.com/m8/feeds/groups/nguyenhuynhutsimple%40gmail.com/base/1b375dcb8e75c96c' deleted='false'/></entry>")
                else
                  puts 'update from google'
                  puts entry.elements['title'].text
                  puts  contact.first_name + ' ' + contact.last_name
                  if  entry.elements['title'].text != (contact.first_name + ' ' + contact.last_name)

                    contact.update_attribute("first_name", entry.elements['title'].text)
                    contact.update_attribute("last_name", ' ')
                  end
                  if entry.elements['gd:phoneNumber'] and entry.elements['gd:phoneNumber'].text != contact.mobile
                    contact.update_attribute("mobile", entry.elements['gd:phoneNumber'].text)
                  end
                  if   Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]) and entry.elements['gd:postalAddress'] and entry.elements['gd:postalAddress'].text != Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ]).full_address
                    address = Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',contact.id ])
                    if entry.elements['gd:postalAddress']
                      address.update_attribute("full_address", entry.elements['gd:postalAddress'].text )
                    end
                  end
                end

              end
            end
          end
        end
      end
    end
  end
  def CrmGoogleContactSync.sync_lead
    google_contact_syncs = CrmGoogleContactSync.find(:all)
    google_contact_syncs.each do |google_contact_sync|
      client = GData::Client::Contacts.new
      lead_group = LeadGroup.find(:first, :conditions =>["crm_google_contact_sync_id = ?", google_contact_sync.id])
      if lead_group == nil
        leads = Lead.find(:all, :conditions =>["user_id = ?", google_contact_sync.user_id])
        leads.each do |lead|

          lead_group = LeadGroup.new
          lead_group.lead = lead
          lead_group.crm_google_contact_sync = google_contact_sync
          lead_group.email = lead.email
          lead_group.save

        end
        if google_contact_sync.token != nil
          client.authsub_token =  google_contact_sync.token
          lead_groups = LeadGroup.find(:all, :conditions =>["crm_google_contact_sync_id = ?", google_contact_sync.id])
          lead_groups.each do |lead_group|
            add_phone_address = ''
            if lead_group.lead.mobile != nil and lead_group.lead.mobile != ''
              add_phone_address = <<-EOF
  <gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>#{lead_group.lead.mobile}</gd:phoneNumber>
              EOF
            end
            if Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',lead_group.lead.id ]) != nil and  Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',lead_group.lead.id ]) != ''
              add_phone_address = <<-EOF
#{add_phone_address}<gd:postalAddress rel='http://schemas.google.com/g/2005#home'>#{Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',lead_group.lead.id ]).full_address}</gd:postalAddress>
              EOF
            end
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
                  #{add_phone_address}
               <gContact:groupMembershipInfo deleted="false" href="#{lead_group.crm_google_contact_sync.lead_group_id}"/>
 </entry>
            EOF

            client.post('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000', entry_str).to_xml

          end
        end
      else
        #delete lead
        delete_lead_groups =  LeadGroup.find(:all, :conditions =>["crm_google_contact_sync_id = ?", google_contact_sync.id])
        delete_lead_groups.each do |delete_lead_group|
          lead = Lead.find(:first, :conditions =>["user_id = ? and id = ?", google_contact_sync.user_id, delete_lead_group.lead_id])
          if lead

            check = false
            client.authsub_token =  google_contact_sync.token
            feed = client.get('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000').to_xml
            puts feed
            feed.elements.each('entry') do |entry|
              gcontact_group_member_ship_info = ''
              gcontact_group_member_ship_info_second = ''
              entry.elements.each("gContact:groupMembershipInfo") do |member|
               
                if gcontact_group_member_ship_info.length < member.attributes["href"].length
                  gcontact_group_member_ship_info = member.attributes["href"]
                else
                  gcontact_group_member_ship_info_second =  member.attributes["href"]
                end
              end
              email = entry.elements["gd:email"].attributes['address']
              if email == lead.email and (gcontact_group_member_ship_info == google_contact_sync.lead_group_id or gcontact_group_member_ship_info_second == google_contact_sync.lead_group_id)
                check = true
              end
            end
            if check == false
              puts 'delete contact'
              lead.destroy
              delete_lead_group.delete
            end
          else
            puts 'bbbb'
            check = false
            delete_entry = nil
            client.authsub_token =  google_contact_sync.token
            feed = client.get('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000').to_xml
            feed.elements.each('entry') do |entry|
              email = entry.elements["gd:email"].attributes['address']
              if email == delete_lead_group.email
                check = true
                delete_entry = entry
              end
            end
            if check == true
              edit_uri = delete_entry.elements["link[@rel='edit']"].attributes['href']
              client.headers['If-Match'] = delete_entry.attribute('etag').value  # make sure we don't nuke another client's updates
              puts 'delete google'
              edit_uri = edit_uri.gsub("%40", '@')
              client.delete(edit_uri)
              delete_lead_group.delete
            end
          end
        end
        leads = Lead.find(:all, :conditions =>["user_id = ?", google_contact_sync.user_id])
        leads.each do |lead|
          lead_group = LeadGroup.find(:first, :conditions => ["lead_id = ?", lead.id])
          if lead_group == nil
            lead_group = LeadGroup.new
            lead_group.lead = lead
            lead_group.crm_google_contact_sync = google_contact_sync
            lead_group.email = lead.email
            lead_group.save
            if google_contact_sync.token != nil
              check = false
              entry_update = nil
              client.authsub_token =  google_contact_sync.token
              feed = client.get('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000').to_xml
              feed.elements.each('entry') do |entry|
                gcontact_group_member_ship_info = ''
                gcontact_group_member_ship_info_second = ''
                entry.elements.each("gContact:groupMembershipInfo") do |member|
                  
                  if gcontact_group_member_ship_info.length < member.attributes["href"].length
                    gcontact_group_member_ship_info = member.attributes["href"]
                  else
                    gcontact_group_member_ship_info_second = member.attributes["href"]
                  end
                end
                email = entry.elements["gd:email"].attributes['address']
                if email == lead.email and (gcontact_group_member_ship_info == google_contact_sync.lead_group_id or gcontact_group_member_ship_info_second == google_contact_sync.lead_group_id)
                  check = true
                  entry_update = entry
                end
              end
              if check == false
                add_phone_address = ''
                if lead.mobile != nil and lead.mobile != ''
                  add_phone_address = <<-EOF
  <gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>#{lead.mobile}</gd:phoneNumber>
                  EOF
                end
                if Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]) != nil and  Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]) != ''
                  add_phone_address = <<-EOF
#{add_phone_address}<gd:postalAddress rel='http://schemas.google.com/g/2005#home'>#{Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]).full_address}</gd:postalAddress>
                  EOF
                end
                entry_str = <<-EOF
                       <entry xmlns="http://www.w3.org/2005/Atom"
                  xmlns:gContact='http://schemas.google.com/contact/2008'
                              xmlns:contact="http://schemas.google.com/contact/2008"
                              xmlns:gd="http://schemas.google.com/g/2005">

                         <category term='http://schemas.google.com/contact/2008#contact'
                                   scheme='http://schemas.google.com/g/2005#kind'/>
                  <title>#{lead.first_name} #{lead.last_name}</title>
                  <content>Belong to Fat Free</content>
                  <gd:name>
                    <gd:fullName>#{lead.first_name} #{lead.last_name}</gd:fullName>
                  </gd:name>
                  <gd:email primary='true' rel='http://schemas.google.com/g/2005#home' address='#{lead.email}'/>
                  #{add_phone_address}
               <gContact:groupMembershipInfo deleted="false" href="#{google_contact_sync.lead_group_id}"/>
 </entry>
                EOF

                client.post('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000', entry_str).to_xml


              else
                if lead.updated_status == true
                  entry_update.elements['title'].text = lead.first_name + '' + lead.last_name
                  entry_update.elements['gd:fullName'].text = lead.first_name + '' + lead.last_name
                  if lead.mobile != nil and lead.mobile != ''
                    entry_update.elements['gd:phoneNumber'].text = lead.mobile
                  end
                  if Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]) != nil and  Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]) != ''
                    entry_update.elements['gd:postalAddress'].text = Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]).full_address
                  end

                  edit_uri = entry_update.elements["link[@rel='edit']"].attributes['href']
                  response = client.put(edit_uri, entry_update.to_s)
                end
              end
            end
          end
        end
        if google_contact_sync.token != nil
          puts 'a'
          client.authsub_token =  google_contact_sync.token
          feed = client.get('https://www.google.com/m8/feeds/contacts/' + google_contact_sync.email + '/full?max-results=100000').to_xml
          puts feed
          feed.elements.each('entry') do |entry|

            gcontact_group_member_ship_info = ''
            gcontact_group_member_ship_info_second = ''
            entry.elements.each("gContact:groupMembershipInfo") do |member|
              
              if gcontact_group_member_ship_info.length < member.attributes["href"].length
                gcontact_group_member_ship_info = member.attributes["href"]
              else
                gcontact_group_member_ship_info_second = member.attributes["href"]
              end
            end


            if gcontact_group_member_ship_info and (gcontact_group_member_ship_info == google_contact_sync.lead_group_id or gcontact_group_member_ship_info_second == google_contact_sync.lead_group_id)
              puts 'abc'
              lead = Lead.find(:first, :conditions => ["user_id = ? AND email = ?",google_contact_sync.user_id,  entry.elements['gd:email'].attributes["address"]])
              if lead == nil
                puts 'ba gia do do'
                lead = Lead.new
                lead.first_name = entry.elements['title'].text
                lead.last_name = '-'
                lead.user_id = google_contact_sync.user_id
                lead.email = entry.elements['gd:email'].attributes["address"]
                if entry.elements['gd:phoneNumber']
                  lead.mobile =  entry.elements['gd:phoneNumber'].text
                end
                lead.save
                puts lead.errors.full_messages
                if entry.elements['gd:postalAddress']
                  address = Address.new
                  address.addressable_id = lead.id
                  address.address_type = "Business"
                  address.full_address = entry.elements['gd:postalAddress'].text
                  address.save
                end
                lead_group = LeadGroup.new
                lead_group.lead = lead
                lead_group.crm_google_contact_sync = google_contact_sync
                lead_group.email = lead.email
                lead_group.save

              else
                if lead.updated_status == true

                  entry.elements['title'].text = lead.first_name + ' ' + lead.last_name
                  if lead.mobile != nil and lead.mobile != ''
                    if entry.elements['gd:phoneNumber'] == nil
                      entry.add_element("<gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>" + lead.mobile + '</gd:phoneNumber>')
                    else
                      entry.elements['gd:phoneNumber'].text = lead.mobile
                    end
                  end
                  if Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]) != nil and  Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]).full_address != ''
                    if entry.elements['gd:postalAddress'] == nil
                      entry.add_element("<gd:postalAddress rel='http://schemas.google.com/g/2005#home'>" +  Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]).full_address + "</gd:postalAddress>")
                    else

                      entry.elements['gd:postalAddress'].text = Address.find(:first , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]).full_address

                    end
                  end
                  lead.update_attribute("updated_status" ,false)
                  puts  entry.elements['gd:postalAddress'].text
                  edit_uri = entry.elements["link[@rel='edit']"].attributes['href']
                  puts edit_uri
                  edit_uri = edit_uri.gsub("%40", '@')
                  client.headers['If-Match'] = entry.attribute('etag').value
                  entry.attribute('etag').remove()
                  entry.add_namespace('http://www.w3.org/2005/Atom')
                  entry.add_namespace('gd','http://schemas.google.com/g/2005')
                  entry.add_namespace('gContact', 'http://schemas.google.com/contact/2008')
                  entry.add_namespace('contact', 'http://schemas.google.com/contact/2008')
                  client.put(edit_uri, entry.to_s)
                  # response = client.put(edit_uri, "<entry xmlns='http://www.w3.org/2005/Atom'
                  #xmlns:gContact='http://schemas.google.com/contact/2008'
                  #           xmlns:contact='http://schemas.google.com/contact/2008'
                  #          xmlns:gd='http://schemas.google.com/g/2005'><id>http://www.google.com/m8/feeds/contacts/nguyenhuynhutsimple%40gmail.com/base/23ded2cb881ad373</id><updated>2011-07-14T09:46:09.671Z</updated><app:edited xmlns:app='http://www.w3.org/2007/app'>2011-07-14T09:46:09.671Z</app:edited><category term='http://schemas.google.com/contact/2008#contact' scheme='http://schemas.google.com/g/2005#kind'/><title>ba gia update a</title><content>Belong to Fat Free</content><link href='https://www.google.com/m8/feeds/photos/media/nguyenhuynhutsimple%40gmail.com/23ded2cb881ad373' gd:etag='&quot;ehlvYWI-bCp7ImBfH3QbSwxRH308fzgvKDY.&quot;' rel='http://schemas.google.com/contacts/2008/rel#photo' type='image/*'/><link href='https://www.google.com/m8/feeds/contacts/nguyenhuynhutsimple%40gmail.com/full/23ded2cb881ad373' rel='self' type='application/atom+xml'/><link href='https://www.google.com/m8/feeds/contacts/nguyenhuynhutsimple%40gmail.com/full/23ded2cb881ad373' rel='edit' type='application/atom+xml'/><gd:email address='huyenanh@gmail.com' rel='http://schemas.google.com/g/2005#home' primary='true'/><gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>update</gd:phoneNumber><gd:postalAddress rel='http://schemas.google.com/g/2005#home'>aa t</gd:postalAddress><gContact:groupMembershipInfo href='http://www.google.com/m8/feeds/groups/nguyenhuynhutsimple%40gmail.com/base/1b375dcb8e75c96c' deleted='false'/></entry>")
                else
                  puts 'update from google'
                  puts entry.elements['title'].text
                  puts  lead.first_name + ' ' + lead.last_name
                  if  entry.elements['title'].text != (lead.first_name + ' ' + lead.last_name)

                    lead.update_attribute("first_name", entry.elements['title'].text)
                    lead.update_attribute("last_name", ' ')
                  end
                  if entry.elements['gd:phoneNumber'] and entry.elements['gd:phoneNumber'].text != lead.mobile
                    lead.update_attribute("mobile", entry.elements['gd:phoneNumber'].text)
                  end
                  if   Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]) and entry.elements['gd:postalAddress'] and entry.elements['gd:postalAddress'].text != Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ]).full_address
                    address = Address.find(:last , :conditions => ['addressable_id = ? And address_type ="Business"',lead.id ])
                    if entry.elements['gd:postalAddress']
                      address.update_attribute("full_address", entry.elements['gd:postalAddress'].text )
                    end
                  end
                end

              end
            end
          end
        end
      end
    end
  end

end
