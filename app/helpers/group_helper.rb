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
    state = "<div style='font-weight:bold;color:blue;background-color:#f0f0ff;margin-bottom:5px;'>"
    if event.past_event?
      return state << '過去のイベントです</div>', ""
    end

    if event.acceptable
      state << (event.date_fixed? ? "開催日は確定済みです" : "開催日は未確定です")
    else
      state << "締め切られています"
    end
    state << "</div>"

    if event.participation?(user_id)
      state << (owner ? '幹事です！' : '参加中です！')
    end

    return state
  end

  def generate_event_informations event, participation, owner
    informations = []
    
    if event.past_event?
      return informations << icon_tag('bullet_red') + 'このイベントは過去に開催されました'
    end
    if participation == nil and event.acceptable
      informations << icon_tag('key') + "このイベントは参加するには事前にグループへの参加が必須です。"

      url_param = {:controller => "group", :action => "new_participation"}
      informations << icon_tag('group_go') + link_to('【このグループへ参加申込みをする】', url_param, {:class => "nyroModal"})
    end
    informations
  end

  def get_events_menu_items selected_menu, participation
    @@menus = [{:name => "イベントの一覧", :menu => "event_list" }]
    @@menus << {:name => "イベントの新規作成", :menu => "event_new" } if participation and participation.waiting != true

    get_menu_items @@menus, selected_menu, "event"
  end

  def get_event_menu_items selected_menu, event_id
    menus = [{:name => "イベントサマリ", :menu => "event_show" },
             {:name => "イベント参加者", :menu => "event_users" },
             {:name => "出席情報", :menu => "event_attendance" }]

    menu_items = []
    menus.each do |menu|
      if menu[:menu] == selected_menu
        menu_items << icon_tag('bullet_red') + "<b>#{menu[:name]}</b>"
      else
        link_to_params = { :action => "event", :menu => menu[:menu], :event_id => event_id }
        menu_items << icon_tag('bullet_blue') + link_to(menu[:name], link_to_params, :confirm => menu[:confirm])
      end
    end
    menu_items
  end

  def get_event_manage_menu_items selected_menu, event_id
    menus = [{:name => "イベントの編集", :menu => "event_edit" } ]

    menu_items = []
    menus.each do |menu|
      if menu[:menu] == selected_menu
        menu_items << icon_tag('bullet_red') + "<b>#{menu[:name]}</b>"
      else
        link_to_params = { :action => "event", :menu => menu[:menu], :event_id => event_id }
        menu_items << icon_tag('bullet_blue') + link_to(menu[:name], link_to_params, :confirm => menu[:confirm])
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
      menu << "<a href=\"#\" id=\"attendee_link_#{options[:event].id}_#{options[:date].id}_#{options[:user_id]}\" class=\"attendee_link\" >[出席]</a>"
      menu << "<a href=\"#\" id=\"absentee_link_#{options[:event].id}_#{options[:date].id}_#{options[:user_id]}\" class=\"absentee_link\" >[欠席]</a>"
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
      icon_tag('help')
    else
      case attendee.state
        when "attend"
        icon_tag('emoticon_happy')
        when "absence"
        icon_tag('cross')       
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
        menus << '<a id="append_date_link" href="#">[候補日の追加]</a>'
      if event.date_fixed? # 確定後
        menus << link_to("[締切]", {:action => 'event_close', :event_id => event.id}, :confirm => "イベントを締め切ります。よろしいですか？")
      end
    else
      menus << link_to("[締切解除]", {:action => 'event_unclose', :event_id => event.id}, :confirm => "イベントの締め切りを解除しますが、よろしいですか？")
    end
    menus
  end

  def generate_date_menu event, participation, owner
    menu = ""
    if participation && owner # 幹事
      menu << generate_owner_menus(event)
    else # 参加者
      if @event.acceptable # 締切前
        menu << '<a id="append_date_link" href="#">[候補日の追加]</a>'
      end
    end
    menu
  end

  def user_state owner
    output = ""
    if owner
      output << icon_tag('star') + '幹事'
    else
      output << icon_tag('user') + '参加者'
    end
    output
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

end
