# -*- coding: undecided -*-
class EventDate < ActiveRecord::Base
  has_many :event_attendees, :dependent => :destroy

  def self.get_date_from_params(time_hash)
    Time.gm(time_hash[:year], time_hash[:month], time_hash[:day], time_hash[:hour], time_hash[:minute])
  end

  def self.valid_date?(date_hash)
    return Date.valid_date?(date_hash[:year].to_i, date_hash[:month].to_i, date_hash[:day].to_i)
  end

  def to_s
    to_date true
  end

  # mm/dd HH:MM 形式で表示
  def to_s_mmdd
    to_date false
  end

private
  def to_date visible_year = false
    wd = %w(月 火 水 木 金 土 日) # Timeクラスの曜日置換方法不明のため

    start_date_format = visible_year ? "%Y/%m/%d(#{wd[start_time.wday-1]}) %H:%M - " : "%m/%d %H:%M - "
    str =  start_time.strftime(start_date_format)
    end_date_format = visible_year ? "%Y/%m/%d(#{wd[end_time.wday-1]})" : "%m/%d"
    str << end_time.strftime(end_date_format) if start_time.strftime("%Y%m%d") != end_time.strftime("%Y%m%d")
    str << end_time.strftime(" %H:%M")
  end

end
