require 'gdata'
class CrmGoogleContactSyncsController < ApplicationController
  # GET /crm_google_contact_syncs
  # GET /crm_google_contact_syncs.xml
  before_filter :require_user
  def index
    @crm_google_contact_syncs = CrmGoogleContactSync.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @crm_google_contact_syncs }
    end
  end

  # GET /crm_google_contact_syncs/1
  # GET /crm_google_contact_syncs/1.xml
  def show
    @crm_google_contact_sync = CrmGoogleContactSync.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @crm_google_contact_sync }
    end
  end

  # GET /crm_google_contact_syncs/new
  # GET /crm_google_contact_syncs/new.xml
  def new
    @crm_google_contact_sync = CrmGoogleContactSync.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @crm_google_contact_sync }
    end
  end

  # GET /crm_google_contact_syncs/1/edit
  def edit
    @crm_google_contact_sync = CrmGoogleContactSync.find(params[:id])
  end

  # POST /crm_google_contact_syncs
  # POST /crm_google_contact_syncs.xml
  def create
    @crm_google_contact_sync = CrmGoogleContactSync.new(params[:crm_google_contact_sync])
    @crm_google_contact_sync.user_id = @current_user.id
    respond_to do |format|
      if @crm_google_contact_sync.save
        format.html { redirect_to(@crm_google_contact_sync, :notice => 'CrmGoogleContactSync was successfully created.') }
        format.xml  { render :xml => @crm_google_contact_sync, :status => :created, :location => @crm_google_contact_sync }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @crm_google_contact_sync.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /crm_google_contact_syncs/1
  # PUT /crm_google_contact_syncs/1.xml
  def update
    @crm_google_contact_sync = CrmGoogleContactSync.find(params[:id])

    respond_to do |format|
      if @crm_google_contact_sync.update_attributes(params[:crm_google_contact_sync])
        format.html { redirect_to(@crm_google_contact_sync, :notice => 'CrmGoogleContactSync was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @crm_google_contact_sync.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /crm_google_contact_syncs/1
  # DELETE /crm_google_contact_syncs/1.xml
  def destroy
    @crm_google_contact_sync = CrmGoogleContactSync.find(params[:id])
    @crm_google_contact_sync.destroy

    respond_to do |format|
      format.html { redirect_to(crm_google_contact_syncs_url) }
      format.xml  { head :ok }
    end
  end
  def sync_google_contact

    next_param = "http://" + request.host_with_port + "/complete_sign_in_google"
    scope_param = 'https://www.google.com/m8/feeds/contacts/default/full%20https://www.google.com/m8/feeds/groups/default/full'
    google_contact = CrmGoogleContactSync.find_by_user_id(@current_user.id)
   # if google_contact
    #  if google_contact.lead_group_id
     #   scope_param = scope_param + "%20" + google_contact.lead_group_id + "%20" + google_contact.contact_group_id
       # scope_param = scope_param + "%20" + "https://www.google.com/m8/feeds/groups/nguyenhuynhutsimple%40gmail.com/full/36d241fc89c6bd97"
    #  end
    #end
    secure_param = "0"
    session_param = "1"
    puts 'scope_param'
    puts scope_param
    root_url = "https://www.google.com/accounts/AuthSubRequest"
    query_string = "?scope=#{scope_param}&session=#{session_param}&secure=#{secure_param}&next=#{next_param}"
    redirect_to root_url + query_string
  end
  def complete_sign_in_google
    client = GData::Client::DocList.new
    client.authsub_token = params[:token] # extract the single-use token from the URL query params
    session[:token] = client.auth_handler.upgrade()
    #client.authsub_token = session[:token] if session[:token]
    #logger.info client.auth_handler.info
    # redirect_to '/'
    feed = client.get('https://www.google.com/m8/feeds/contacts/default/full?max-results=0').to_xml
    google_contact =  CrmGoogleContactSync.find_by_email(feed.elements['author'].elements['email'].text)
    if google_contact
      if google_contact.lead_group_id
        feed = client.get('https://www.google.com/m8/feeds/groups/default/full').to_xml
        feed.elements.each('entry') do |entry|

          if entry.elements["link[@rel='edit']"] and entry.elements["link[@rel='edit']"].attributes['href'] == google_contact.lead_group_id
            puts 'google_contact.lead_group_id'
            puts google_contact.lead_group_id
        #    client.delete(google_contact.lead_group_id)

          end
          if  entry.elements["link[@rel='edit']"] and entry.elements["link[@rel='edit']"].attributes['href'] == google_contact.contact_group_id
            puts 'google_contact.contact_group_id'
            puts google_contact.contact_group_id
          #  client.delete(google_contact.contact_group_id)

          end
        end
      end
      feed = client.get('https://www.google.com/m8/feeds/groups/default/full').to_xml
      entry_str = <<-EOF

                       <entry xmlns="http://www.w3.org/2005/Atom"

                              xmlns:gd="http://schemas.google.com/g/2005">

                         <category term='http://schemas.google.com/contact/2008#group'
                                   scheme='http://schemas.google.com/g/2005#kind'/>
     <title>
#{google_contact.contact_group}
    </title>
                  <content>Belongs to Fat Free</content>

  </entry>

      EOF
      feed_contact = client.post('https://www.google.com/m8/feeds/groups/default/full', entry_str).to_xml
          edit_uri_contact = feed_contact.elements["link[@rel='edit']"].attributes['href']
       uri_contact_id = feed_contact.elements['id'].text
      entry_str = <<-EOF

                       <entry xmlns="http://www.w3.org/2005/Atom"

                              xmlns:gd="http://schemas.google.com/g/2005">

                         <category term='http://schemas.google.com/contact/2008#group'
                                   scheme='http://schemas.google.com/g/2005#kind'/>
     <title>
#{google_contact.lead_group}
    </title>
                  <content>Belongs to Fat Free</content>
  </entry>

      EOF
      feed_lead = client.post('https://www.google.com/m8/feeds/groups/default/full', entry_str).to_xml
      edit_uri_lead = feed_lead.elements["link[@rel='edit']"].attributes['href']
      uri_lead_id = feed_lead.elements['id'].text
      google_contact.update_attributes(:lead_group_id =>  edit_uri_lead, :contact_group_id => edit_uri_contact)
     puts @current_user.contacts
     puts 'cccc'
      @current_user.contacts.each do |contact|
        puts contact.email
        puts 'contact'
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
               <gContact:groupMembershipInfo deleted="false" href="#{uri_contact_id}"/>
 </entry>
  EOF
  client.post('https://www.google.com/m8/feeds/contacts/default/full', entry_str).to_xml
      end
      puts 'llllll'
      puts @current_user.leads
            @current_user.leads.each do |lead|
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
               <gContact:groupMembershipInfo deleted="false" href="#{uri_lead_id}"/>
 </entry>
  EOF
  client.post('https://www.google.com/m8/feeds/contacts/default/full', entry_str).to_xml
      end
    else
      flash[:notice] = "You don't have access to this section"
      redirect_to '/'
      return
    end

    redirect_to '/'
    return
  end
end
