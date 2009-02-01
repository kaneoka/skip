class EventDateUserComment < ActiveRecord::Base
  belongs_to :event_date
  belongs_to :group_participation
end
