class EventAttendee < ActiveRecord::Base
  belongs_to :event_date
  belongs_to :group_participation
  belongs_to :user
end
