
require 'rubygems'
require 'rufus/scheduler'

## to start scheduler
scheduler = Rufus::Scheduler.start_new

## It will print message every i minute
scheduler.every("1m") do
  puts 'Check Google Contact Sync'
  CrmGoogleContactSync.sync_lead
  CrmGoogleContactSync.sync_contact
  puts 'End'
end
