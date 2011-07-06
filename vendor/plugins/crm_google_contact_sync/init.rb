# Include hook code here
require File.join(File.dirname(__FILE__), 'rails', 'init')
require "fat_free_crm"
require "crm_google_contact_syncs"
FatFreeCRM::Plugin.register(:crm_google_contact_syncs, initializer) do
          name "Fat Free Invoice"
        author "Brett Dawkins"
       version "0.1"
   description "Basic invoice tracking"
  dependencies :erb
           tab :main, :text => "Invoices", :url => { :controller => "crm_google_contact_syncs" }
end


Hash.class_eval do
  def is_a_special_hash?
    true
  end
end