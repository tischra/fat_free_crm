ActionController::Routing::Routes.draw do |map|

 map.resources :crm_google_contact_syncs
   map.complete_sign_in_google 'complete_sign_in_google', :controller => "crm_google_contact_syncs", :action => 'complete_sign_in_google'
map.sync_google_contact 'sync_google_contact', :controller => "crm_google_contact_syncs", :action => 'sync_google_contact'

end
