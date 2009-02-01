# -*- coding: utf-8 -*-
class Event < ActiveRecord::Base
  has_many :event_dates, :order => "start_time", :dependent => :destroy

  has_many :event_owners, :dependent => :destroy
  has_many :group_participations

  validates_presence_of :name ,:description, :place,
                        :message => 'は必須です'

  validates_length_of   :name, :maximum => 100, :message => 'は100桁以内で入力してください'

  class << self
    HUMANIZED_ATTRIBUTE_KEY_NAMES = {
      "name" => "名前",
      "description" => "説明",
      "place" => "場所",
      "capacity" => "最大参加人数",
    }
    def human_attribute_name(attribute_key_name)
      HUMANIZED_ATTRIBUTE_KEY_NAMES[attribute_key_name] || super
    end
     def symbol_type
       :gid
     end
  end

  def holdingDatetime
    return "" unless self.date_fixed?
    result = self.holding_date.start_time.strftime("%Y年%m月%d日")
    result << " "
    result << self.holding_date.start_time.strftime("%H:%M")
    result << " ～ "
    result << self.holding_date.end_time.strftime("%H:%M")
    return result

  end

  #開催日
  def holding_date
    self.event_dates.each do |event_date|
      return event_date if event_date.fixed_date == true
    end
  end

  def participation? user_id
    group = Group.find_by_gid(self.gid)
    result = false
    result = true if group.group_participations.find_by_user_id(user_id)
    return result
  end

  def past_event?(current_date = Time.now)
    result = false
    if self.date_fixed?
      result = true if self.holding_date.end_time < current_date
    else
      result = true if event_dates.map{|date| date.end_time}.max < current_date
    end
    return result
  end

  def fixed_date_or_last_candidate_date
    if date_fixed?
      result = self.holding_date.end_time
    else
      result = event_dates.map{|date| date.end_time}.max
    end
  end

   def symbol_id
     gid
   end

  def symbol
    self.class.symbol_type.to_s + ":" + symbol_id
  end

  def owner? user_id
    result = false
    self.event_owners.each { |owner| result = true if owner.user_id == user_id }
    result
  end

  def event_admin_users
    admin_users = []
    self.event_owners.each do |users|
      admin_users << users.user.name 
    end
    admin_users.join(" ")
  end

  #確定日があるかどうか
  def date_fixed?
    result = false
    self.event_dates.each do |event_date|
      result = true if event_date.fixed_date == true
    end
    return result
  end

end
