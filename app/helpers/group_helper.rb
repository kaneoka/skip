# -*- coding: utf-8 -*-
# SKIP(Social Knowledge & Innovation Platform)
# Copyright (C) 2008 TIS Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

module GroupHelper
  include BoardEntriesHelper
  include UsersHelper
  include GroupsHelper

  # 管理メニューの生成
  def get_manage_menu_items selected_menu
    @@menus = [{:name => "グループ情報変更", :menu => "manage_info" },
               {:name => "参加者管理",       :menu => "manage_participations"} ]
    @@menus << {:name => "参加者の承認",     :menu => "manage_permit" } if @group.protected?

    get_menu_items @@menus, selected_menu, "manage"
  end

  def get_select_user_options owners
    options_hash = {}
    owners.each { |owner| options_hash.store(owner.name, owner.id) }
    options_hash
  end

 ###イベントに関するhelper

  def generate_event_visitor_state event, participation, owner, user_id

    return if event.past_event?

    state = "<div style='margin-top:5px;margin-bottom: 5px;'>"

    if participation == nil and event.acceptable
      state << icon_tag('key') + "このイベントは参加するには事前にグループへの参加が必須です。"
      state << "</div><div style='margin-left:25px;'>"
      url_param = {:controller => "group", :action => "new_participation"}
      state << icon_tag('group_go') + link_to('【このグループへ参加申込みをする】', url_param, {:class => "nyroModal"})
      state << "</div>"
      return state
    end
    
    if event.acceptable
      if event.holding_date
        unless ea = EventAttendee.find_by_event_date_id_and_user_id(event.holding_date.id, user_id)
          state << icon_tag('lightbulb') + "開催日の出欠情報が入力されていません。"
        else
          if ea.state == "pending"
            state << icon_tag('lightbulb') + "開催日の出欠情報が入力されていません。"
          end
        end
      else
        event.event_dates.each do |event_date|
          unless EventAttendee.find_by_event_date_id_and_user_id(event_date.id, user_id)
            state << icon_tag('lightbulb') + "出欠情報が入力されていない候補日があります。"
            break
          end
        end
      end
    end
    
    state << "</div>"

    state << "<div style='margin-top: 5px;margin-bottom:5px;'>"

    if owner
      if event.acceptable
        unless event.holding_date
          state << icon_tag('lightbulb') + "開催日が確定していません。開催日を確定してください。"
        else
          state << icon_tag('lightbulb') + "出欠登録を締め切ることができます。"
          state << "</div><div style='margin-left:25px;'>"
          state << icon_tag('cut') + generate_owner_menus(event)
        end
      else
          state << icon_tag('lightbulb') + "出欠登録の締め切りを解除することができます。"
          state << "</div><div style='margin-left:25px;'>"
          state << icon_tag('cut') + generate_owner_menus(event)
      end
    end

    state << "</div>"

    return state
  end

  def generate_event_informations event, participation, owner
    informations = []

    informations = "<div style='margin-top:5px;margin-bottom: 5px;'>"

    if event.past_event?
      informations << icon_tag('information') + 'このイベントは過去に開催されました'
      informations << "</div>"
      return informations
    end
    
    if event.acceptable
      if event.holding_date
        informations << "</div><div style='margin-top:5px;margin-bottom: 5px;'>"
        informations << icon_tag('information') + "開催日が確定済みです"
      else
        unless owner
          informations << "</div><div style='margin-top:5px;margin-bottom: 5px;'>"
          informations << icon_tag('information') + "開催日が確定していません。"
        end
      end
    else
      informations << "</div><div style='margin-top:5px;margin-bottom: 5px;'>"    
      informations << icon_tag('information') + "イベントの詳細が確定しました。開催日と開催場所を確認してください。"
    end

    informations << "</div>"

    informations
  end

  def get_events_menu_items selected_menu, participation
    menus = [{:name => "イベントの一覧", :menu => "event" }]
    menus << {:name => "イベントの新規作成", :menu => "event_new" } if participation and participation.waiting != true

    menu_items = []
    menus.each do |menu|
      if menu[:menu] == selected_menu
        menu_items << icon_tag('bullet_red') + "<b>#{menu[:name]}</b>"
      else
        link_to_params = { :action => menu[:menu] }
        menu_items << icon_tag('bullet_blue') + link_to(menu[:name], link_to_params, :confirm => menu[:confirm])
      end
    end
    menu_items
  end

  def get_event_manage_menu_items selected_menu, event_id
    menus = [{:name => "[イベントを編集する]", :menu => "event_edit" } ]

    menu_items = []
    menus.each do |menu|
      if menu[:menu] == selected_menu
        menu_items << "<b>#{menu[:name]}</b>"
      else
        link_to_params = { :action => menu[:menu], :event_id => event_id }
        menu_items << link_to(menu[:name], link_to_params, :confirm => menu[:confirm])
      end
    end
    menu_items
  end



  # 候補日一覧に表示するメニューを状況に応じて出力する
  # 表示したい文字列を返す

  def generate_attendee_menu options={}
    options.assert_valid_keys [:event, :date, :attendee, :user_id, :owner]
    menu = ""
    if options[:event].acceptable || options[:owner]
      menu << "<nobr>"
      menu << "<a href=\"#\" id=\"attendee_link_#{options[:event].id}_#{options[:date].id}_#{options[:user_id]}\" class=\"attendee_link\" >[出席]</a>"
      menu << "<a href=\"#\" id=\"absentee_link_#{options[:event].id}_#{options[:date].id}_#{options[:user_id]}\" class=\"absentee_link\" >[欠席]</a>"
      menu << "</nobr>"
    else
      if options[:attendee] and options[:attendee].state == "attend"
        menu << link_to("[キャンセル]", { :action => :event_cancel, :event_id => options[:event].id, :event_date_id => options[:date].id, :user_id => options[:user_id] },
                                          :method => :post, :confirm => "本当にキャンセルしますか？")
      end
    end
    menu
  end

  # 開催日に関係するメニューを出力する
  def generate_fixed_date_menu event, date, owned
    output = ""
    if fixed_date? event, date
      output = "開催日です"
    elsif event.acceptable and owned
      output << link_to("[確定]", {:action => :fix_date, :event_id => event.id, :event_date_id => date.id},
                                  :confirm => "本当に確定しますか？", :method => :post) if date.start_time > Time.now
      output << link_to("[削除]", {:action => :delete_date, :event_id => event.id, :event_date_id => date.id},
                                  :confirm => "本当に削除しますか？", :method => :post) if event.event_dates.size > 1
     end
    output
  end

  def show_attendees_state date, attendee
    unless attendee
      ""
    else
      case attendee.state
      when "attend"
        icon_tag('emoticon_happy') + "出席"
      when "absence"
        icon_tag('cross') + "欠席"
      end
    end
  end
  
  # 指定日がイベントの開催日か否か
  def fixed_date? event, date
    event.event_dates && date.fixed_date == true
  end

  def generate_owner_menus event 
    menus = ""
    if event.acceptable # 締切前
      if event.date_fixed? # 確定後
        menus << link_to("[出欠登録を締め切る]", {:action => 'event_close', :event_id => event.id}, :confirm => "イベントを締め切ります。よろしいですか？")
      end
    else
      menus << link_to("[出欠登録の締め切りを解除する]", {:action => 'event_unclose', :event_id => event.id}, :confirm => "イベントの締め切りを解除しますが、よろしいですか？")
    end
    menus
  end

  def generate_date_menu event, participation, owner
    menu = ""
      if @event.acceptable # 締切前
        menu << '<a id="append_date_link" href="#">[候補日の追加]</a>'
      end
    menu
  end

  # 開催日選択のセレクトボックスに使用する配列を生成する
  def get_date_select_values event
    date_select_values = []
    @event.event_dates.each do |date|
      date_str = date.to_s_mmdd
      date_str << " [開催日]" if date.fixed_date == true
      date_select_values << [date_str, date.id.to_s]
    end
    date_select_values
  end

  def time_options
    time_options = []
    for hour in 0..23
      for minute in 0..3
        val = hour.to_s.rjust(2, '0') + ":" + (minute * 15).to_s.rjust(2, '0')
        time_options << [val, val]
      end
    end
    time_options
  end

  def show_event_admin_users event
    limit = 5
    admin_users = []
    event.event_owners.each_with_index do |users, index|
      admin_users << users.user.name 
      break if index >= (limit - 1)
    end

     state = "<span style='float: left;'>"
     state << admin_users.join(" , ")
     state << "</span>"
    if event.event_owners.size > limit
      state << "<span style='float: right;'>"
      state <<  link_to("[すべてを見る]", :action => "event_users", :event_id => event.id)
      state << "</span>"
    end
    state
  end

  def show_event_admin_users_link users, event
    limit = 5
    admin_users = []
    users.each_with_index do |user, index|
      admin_users << user_link_to(user)
      break if index >= (limit - 1)
    end

    state = admin_users.join(" , ")
    if users.size > limit
      state << "<span style='padding-left:100px;'>"
      state <<  link_to("[すべてを見る]", :action => "event_users", :event_id => event.id)
      state << "</span>"
    end
    state
  end

end
