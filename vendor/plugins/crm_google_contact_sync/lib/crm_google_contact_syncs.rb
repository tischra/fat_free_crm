# CrmGoogleContactSync
#require "controllers/crm_google_contact_syncs_controller"
#require "models/crm_google_contact_sync"
%w{ models controllers views }.each do |dir|
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH << path
  ActiveSupport::Dependencies.load_paths << path
  ActiveSupport::Dependencies.load_once_paths.delete(path)
end