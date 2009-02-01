class CreateEventTable < ActiveRecord::Migration
  def self.up

    create_table "event_attendees" do |t|
      t.integer  "user_id",                :null => false
      t.integer  "event_date_id",          :null => false
      t.string   "state"
      t.datetime "updated_on",             :null => false
      t.integer  "group_participation_id", :null => false
      t.string   "comment"
    end

    create_table "event_dates" do |t|
      t.integer  "event_id",   :null => false
      t.datetime "start_time", :null => false
      t.datetime "end_time",   :null => false
      t.boolean  "fixed_date", :null => false
      t.datetime "updated_on", :null => false
    end

    create_table "events" do |t|
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "name",        :limit => 200, :default => "", :null => false
      t.text     "description",                :default => "", :null => false
      t.text     "place",                      :default => "", :null => false
      t.string   "gid",                                        :null => false
      t.string   "eid",         :limit => 100, :default => "", :null => false
      t.boolean  "acceptable",                                 :null => false
      t.string   "publication_symbol",         :default => "", :null => false
    end

    create_table "event_owners" do |t|
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "event_id",                      :null => false
      t.integer  "user_id",                       :null => false
    end

    add_index "events", ["eid"], :name => "index_events_on_eid", :unique => true

  end

  def self.down
    drop_table :event_attendees
    drop_table :event_dates
    drop_table :events
    drop_table :event_owners
  end

end
