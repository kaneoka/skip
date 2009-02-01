# -*- coding: utf-8 -*-
class Event < ActiveRecord::Base
  has_many :event_dates, :order => "start_time", :dependent => :destroy
  has_one :event_publication, :dependent => :destroy
  has_one :event_fixed_date, :dependent => :destroy

  has_many :event_owners, :dependent => :destroy
  has_many :group_participations

  validates_presence_of :eid, :name ,:description, :place,
                        :message => 'は必須です'

  validates_length_of   :name, :maximum => 100, :message => 'は100桁以内で入力してください'

  validates_uniqueness_of :eid, :message => 'は既に登録されています'
  validates_length_of :eid, :minimum => 4, :message => 'は4文字以上で入力してください'
  validates_length_of :eid, :maximum => 50, :message => 'は50文字以内で入力してください'
  validates_format_of :eid, :message => 'は数字orアルファベットor記号(ハイフン「-」 アンダーバー「_」)で入力してください', :with => /^[a-zA-Z0-9\-_]*$/

  class << self
    HUMANIZED_ATTRIBUTE_KEY_NAMES = {
      "eid"  => "イベントID",
      "name" => "名前",
      "description" => "説明",
      "place" => "場所",
      "capacity" => "最大参加人数",
    }
    def human_attribute_name(attribute_key_name)
      HUMANIZED_ATTRIBUTE_KEY_NAMES[attribute_key_name] || super
    end
    def symbol_type
      :eid
    end
  end

  def holdingDatetime
    return "" unless event_fixed_date.event_date
    result = self.holding_date.strftime("%Y年%m月%d日")
    result << " "
    result << event_fixed_date.event_date.start_time.strftime("%H:%M")
    result << " ～ "
    result << event_fixed_date.event_date.end_time.strftime("%H:%M")
    return result
  end

  #開催日
  def holding_date
    event_fixed_date.event_date.start_time.to_date
  end

  def finished?(current_date = Time.now)
    result = false
    unless acceptable
      result = true if event_fixed_date and event_fixed_date.event_date.end_time < current_date
      result = true unless event_fixed_date
    end
    return result
  end

  def participation? user_id
    group = Group.find_by_gid(self.gid)
    result = false
    result = true if group.group_participations.find_by_user_id(user_id)
    return result
  end

  def should_close_event?(current_date = Time.now)
    result = false
    if acceptable
      if event_dates.map{|date| date.end_time}.max < current_date
        result = true
      end
    end
      return result
  end

  def symbol_id
    eid
  end

  def symbol
    self.class.symbol_type.to_s + ":" + symbol_id
  end

  def owner? user_id
    result = false
    self.event_owners.each { |owner| result = true if owner.user_id == user_id }
    result
  end

end
