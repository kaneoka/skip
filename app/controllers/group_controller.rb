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

class GroupController < ApplicationController
  helper 'board_entries'
  before_filter :load_group_and_participation, :setup_layout

  before_filter :check_owned,
                :only => [ :manage, :managers, :permit,
                           :update, :destroy, :toggle_owned,
                           :forced_leave_user, :change_participation, :append_user ]

  verify :method => :post,
         :only => [ :join, :destroy, :leave, :update, :change_participation,
                    :ado_set_favorite, :toggle_owned, :forced_leave_user, :append_user ],
         :redirect_to => { :action => :show }

  verify :method => :post,
         :only => [ :event_destroy, :event_cancel,
                    :fix_date, :delete_date, :append_date],
         :redirect_to => { :action => :event }

  # tab_menu
  def show
    @admin_users = @group.participation_users :order => "group_participations.updated_on DESC",
                                              :owned => true,
                                              :waiting => false
    @users = @group.participation_users :limit => 20,
                                        :order => "group_participations.updated_on DESC",
                                        :owned => false,
                                        :waiting => false
    @recent_messages = BoardEntry.find_visible(5, login_user_symbols, @group.symbol)
  end

  # tab_menu
  def users
    params[:condition] = {} unless params[:condition]
    params[:condition].merge!(:with_group => @group.id)
    @condition = UserSearchCondition.create_by_params params

    @pages, @users = paginate(:user,
                              :per_page => @condition.value_of_per_page,
                              :conditions => @condition.make_conditions,
                              :order_by => @condition.value_of_order_by,
                              :include => @condition.value_of_include)
    unless @users && @users.size > 0
      flash.now[:notice] = _('該当するユーザは存在しませんでした。')
    end
  end

  # tab_menu
  def bbs
    order = "last_updated DESC,board_entries.id DESC"
    options = { :symbol => @group.symbol }

    # 左側
    setup_bbs_left_box options

    # 右側
    if entry_id = params[:entry_id]
      options[:id] = entry_id
      find_params = BoardEntry.make_conditions(login_user_symbols, options)

      @entry = BoardEntry.find(:first,
                               :order => order,
                               :conditions => find_params[:conditions],
                               :include => find_params[:include] | [ :user, :board_entry_comments, :state ])

      if @entry
        login_user_id = session[:user_id]
        @entry.accessed(login_user_id)
        @prev_entry, @next_entry = @entry.get_around_entry(login_user_symbols)
        @editable = @entry.editable?(login_user_symbols, session[:user_id], session[:user_symbol], login_user_groups)
        @tb_entries = @entry.trackback_entries(login_user_id, login_user_symbols)
        @to_tb_entries = @entry.to_trackback_entries(login_user_id, login_user_symbols)
        @title += " - " + @entry.title

        @entry_accesses =  EntryAccess.find_by_entry_id @entry.id
        @total_count = @entry.state.access_count
        bookmark = Bookmark.find(:first, :conditions =>["url = ?", "/page/"+@entry.id.to_s])
        @bookmark_comments_count = bookmark ? bookmark.bookmark_comments_count : 0
      end
    else
      options[:category] = params[:category]
      options[:keyword] = params[:keyword]

      params[:sort_type] ||= "date"
      if params[:sort_type] == "access"
        order = "board_entry_points.access_count DESC"
      end

      find_params = BoardEntry.make_conditions(login_user_symbols, options)

      if @user = params[:user]
        find_params[:conditions][0] << " and board_entries.user_id = ?"
        find_params[:conditions] << @user
      end

      @pages, @entries = paginate(:board_entries,
                                  :per_page => 20,
                                  :order => order,
                                  :conditions => find_params[:conditions],
                                  :include => find_params[:include] | [ :user, :board_entry_comments, :state ])
    end

  end

  # tab_menu
  def new
    redirect_to_with_deny_auth and return unless login_user_groups.include? @group.symbol

    redirect_to(:controller => 'edit',
                :action => '',
                :entry_type => BoardEntry::GROUP_BBS,
                :symbol => @group.symbol,
                :publication_type => "private")
  end

  # tab_menu
  def new_participation
    render :layout => 'dialog'
  end

  # tab_menu
  def manage
    @menu = params[:menu] || "manage_info"

    case @menu
    when "manage_info"
      @group_categories = GroupCategory.all
    when "manage_participations"
      @pages, @participations = paginate_participations(@group, false)
    when "manage_permit"
      unless @group.protected?
        flash[:warning] = "参加に承認は不要です"
        redirect_to :action => :manage
        return
      end
      @pages, @participations = paginate_participations(@group, true)
    end
    render :partial => @menu, :layout => "layout"
  end

  # tab_menu
  def share_file
    params.store(:owner_name, @group.name)
    params.store(:visitor_is_uploader, @participation)
    text = render_component_as_string :controller => 'share_file', :action => 'list', :id => @group.symbol, :params => params
    render :text => text, :layout => 'layout'
  end

  # post_action
  # 参加申込み
  def join
    if @participation
      flash[:notice] = '既に参加しています。'
    else
      participation = GroupParticipation.new(:user_id => session[:user_id], :group_id => @group.id)
      participation.waiting = true if @group.protected?

      if participation.save
        if participation.waiting?
          flash[:notice] = '参加申し込みをしました。承認されるのをお待ちください。'
        else
          login_user_groups << @group.symbol
          flash[:notice] = 'グループに参加しました。'
        end

        message = params[:board_entry][:contents]

        #グループのownerのシンボル(複数と取ってきて、publication_symbolsに入れる)
        owner_symbols = @group.get_owners.map { |user| user.symbol }
        entry_params = { }
        entry_params[:title] = "参加申し込みをしました！"
        entry_params[:message] = render_to_string(:partial => 'entries_template/group_join',
                                                  :locals => { :user_name => current_user.name,
                                                               :message => message })
        entry_params[:tags] = "参加申し込み"
        entry_params[:tags] << ",#{Tag::NOTICE_TAG}" if @group.protected?
        entry_params[:user_symbol] = session[:user_symbol]
        entry_params[:user_id] = session[:user_id]
        entry_params[:entry_type] = BoardEntry::GROUP_BBS
        entry_params[:owner_symbol] = @group.symbol
        entry_params[:publication_type] = 'protected'
        entry_params[:publication_symbols] = owner_symbols + [session[:user_symbol]]

        board_entry =  BoardEntry.create_entry(entry_params)
      end
    end
    redirect_to :action => 'show'
  end

  # post_action
  # 退会
  def leave
    if @participation
      @participation.destroy
      login_user_groups.delete(@group.symbol)
      flash[:notice] = '退会しました。'
    else
      flash[:notice] = 'そのグループには参加していません。'
    end
    redirect_to :action => 'show'
  end

  # post_action ... では無いので後に修正が必要
  # 管理者変更
  def toggle_owned
    group_participation = GroupParticipation.find(params[:participation_id])

    redirect_to_with_deny_auth and return unless group_participation.user_id != session[:user_id]

    group_participation.owned = !group_participation.owned?

    if group_participation.save
      flash[:notice] = '変更しました。'
    else
      flash[:warning] = '権限変更に失敗しました。'
    end
    redirect_to :action => 'manage', :menu => 'manage_participations'
  end

  # 管理者による強制退会処理
  def forced_leave_user
    group_participation = GroupParticipation.find(params[:participation_id])

    redirect_to_with_deny_auth and return unless group_participation.group_id == @participation.group_id

    user = group_participation.user
    group_participation.destroy

    # BBSにuid直接指定[連絡]で新規投稿(自動で投稿されて保存される)
    entry_params = { }
    entry_params[:title] ="【#{@group.name}】退会処理"
    entry_params[:message] = "[#{@group.symbol}>]から#{user.name}さんの退会処理を実行しました"
    entry_params[:tags] = "#{Tag::NOTICE_TAG}"
    entry_params[:user_symbol] = session[:user_symbol]
    entry_params[:user_id] = session[:user_id]
    entry_params[:entry_type] = BoardEntry::GROUP_BBS
    entry_params[:owner_symbol] = @group.symbol
    entry_params[:publication_type] = 'protected'
    entry_params[:publication_symbols] = [session[:user_symbol]]
    entry_params[:publication_symbols] << user.symbol
    entry = BoardEntry.create_entry(entry_params)

    flash[:notice] = "退会者向けに掲示板にメッセージを作成しました。内容は必要に応じて変更してください"
    redirect_to :action => 'bbs', :entry_id => entry.id
  end

  # post_action
  # 参加の許可か棄却
  def change_participation
    unless @group.protected?
      flash[:warning] = "参加に承認は不要です"
      redirect_to :action => :show
    end
    type_name = params[:submit_type] == 'permit' ? "許可" : "棄却"

    if states = params[:participation_state]
      states.each do |participation_id, state|
        if state == 'true'
          participation = GroupParticipation.find(participation_id)
          if participation.group_id == @participation.group_id &&
            !participation.waiting
            flash[:warning] = "このグループに参加済みのユーザが含まれています。"
            redirect_to :action => 'manage', :menu => 'manage_permit'
            return false
          end
          result = nil
          if params[:submit_type] == 'permit'
            participation.waiting = false
            result = participation.save
          else
            result = participation.destroy
          end

          flash[:notice] = type_name + ( result ? 'しました。' : 'に失敗しました。')
        end
      end
    end
    redirect_to :action => 'manage', :menu => 'manage_permit'
  end

  # post_action
  # 更新
  def update
    if @group.update_attributes(params[:group])
      flash.now[:notice] = 'グループ情報は正しく更新されました。'
    end
    manage
  end

  # post_action
  # 削除
  def destroy
    if @group.group_participations.size > 1
      flash[:warning] = '自分以外のユーザがまだ存在しています。削除できません。'
      redirect_to :action => 'show'
    else
      @group.destroy
      flash[:notice] = 'グループは削除されました。'
      redirect_to :controller => 'groups'
    end
  end

  # ajax action
  # お気に入りのステータスを設定する
  def ado_set_favorite
    par_id = params[:group_participation_id]
    favorite_flag = params[:favorite_flag]
    participation = @group.group_participations.find(par_id)
    if participation.user_id != session[:user_id]
      render :nothing => true
      return false
    end
    participation.update_attribute(:favorite, favorite_flag)
    render :partial => "groups/favorite", :locals => { :gid => @group.gid, :participation => participation, :update_elem_id => params[:update_elem_id]}
  end

  # 参加者追加(管理者のみ)
  def append_user
    # 参加制約は追加しない。制約は制約管理で。
    symbol_type, symbol_id = Symbol.split_symbol params[:symbol]
    case symbol_type
    when 'uid'
      user = User.find_by_uid(symbol_id)
      if @group.group_participations.find_by_user_id(user.id)
        flash[:notice] = "#{user.name}さんは既に参加済み/参加申請済みです。"
      else
        @group.group_participations.build(:user_id => user.id, :owned => false)
        @group.save
        flash[:notice] = "#{user.name}さんを参加者に追加し、連絡の掲示板を作成しました。"
      end
    when 'gid'
      group = Group.find_by_gid(symbol_id, :include => :group_participations)
      group.group_participations.each do |participation|
        unless @group.group_participations.find_by_user_id(participation.user_id)
          @group.group_participations.build(:user_id => participation.user_id, :owned => false)
        end
      end
      @group.save
      flash[:notice] = "#{group.name}のメンバーを参加者に追加し、連絡の掲示板を作成しました。"
    else
      flash[:warning] = "ユーザ／グループの指定方法が間違っています"
    end

    # BBSにsymbol直接指定[連絡]で新規投稿(自動で投稿されて保存される)
    @group.create_entry_invite_group(session[:user_id],
                                     session[:user_symbol],
                                     [params[:symbol], session[:user_symbol]])

    redirect_to :action => 'manage', :menu => 'manage_participations'
  end

  def event_new
    @event = Event.new

    @event.event_dates << EventDate.new(:start_time => Time.now, :end_time => (Time.now + (60*60)))
    params[:publication_type] = "public"
  end
  
  def event
    condition_params = login_user_symbols + [Symbol::SYSTEM_ALL_USER]
    conditions =["gid = ? and publication_symbol in (?)",@group.gid,condition_params]
    
    unless @inculde_past_event = params[:include_past_event] 
      conditions[0] << "and end_time > ? "
      conditions << Time.now
    end
    
    if params[:keyword]
      conditions[0] << "and name like ?"
      conditions << "%" + params[:keyword] + "%"
    end
    
    @pages, @events = paginate(:events,
                               :per_page => 10,
                               :conditions => conditions,
#                               :order => ['event_dates.end_time desc'],
                               :order => ['event_dates.fixed_date desc , event_dates.end_time desc'],
                               :include => ['event_dates'])
    unless @events && @events.size > 0
      flash.now[:notice] = 'イベントはありませんでした。'
    end
  end

  def event_edit
    
    if @event = Event.find(params[:event_id])
      params[:publication_type] = @event.publication_symbol == 'sid:allusers' ? 'public' :'private'
    end
    
    per_page = 30
    group = Group.find_by_gid(@event.gid)
    conditions =["group_participations.group_id = ? ",group.id]
    
    @admin_users = User.find(:all,
                             :order=>"group_participations.updated_on DESC",
                             :conditions=>["group_participations.group_id = ? and event_owners.event_id = ? ", group.id, @event.id],
                             :include=>[:group_participations,:event_owners])
    
    @pages, @users = paginate(:user,
                              :per_page => per_page,
                              :conditions => conditions,
                              :include => "group_participations"
                              )
    
    @owner = false
    @owner = true if @event.event_owners.find_by_user_id(current_user.id)
  end

  def event_show
    if @event = Event.find(params[:event_id] )
      group = Group.find_by_gid(@event.gid)

      flash[:warning] ||= nil
    else
      flash[:warning] = "イベントはありませんでした"
      redirect_to :action => "event"
      return false
    end
    
    @admin_users = User.find(:all,
                             :order=>"group_participations.updated_on DESC",
                             :conditions=>["group_participations.group_id = ? and event_owners.event_id = ? ", group.id, @event.id],
                               :include=>[:group_participations,:event_owners])
    @users       = User.find(:all,
                             :limit=>30,
                             :order=>"group_participations.updated_on DESC",
                             :conditions=>["group_participations.group_id = ?",group.id],
                             :include=>[:group_participations])
    @users -= @admin_users
    
    @participation = group.group_participations.find_by_user_id(current_user.id)
    @owner = false
    @owner = true if @event.event_owners.find_by_user_id(current_user.id)

  end

  def event_users
    params[:include_absentee] ||= "participation"
    
    @event = Event.find(params[:event_id])
    group = Group.find_by_gid(@event.gid)
    per_page = 30
    
    conditions =["group_participations.group_id = ? ",group.id]
    
    if params[:user_name]
      conditions[0] << "and users.name like (?)"
      conditions << "%" + params[:user_name] + "%"
    end
    
    unless params[:include_absentee] == "participation"
      #全参加者でないときは、出席情報、コメント情報を取得(必ず日付が指定されている)
      event_date = @event.event_dates.find(params[:date])
      
      if params[:include_absentee] == "attendee"
        # 出席者のみ
        conditions[0] << " and event_attendees.event_date_id = ?  and event_attendees.state = ? "
        conditions << params[:date]
        conditions << "attend"
      end
    end
    
    event_date_ids = @event.event_dates.map{ |date| date.id }
    
    @attendees_hash = { }
    event_date_ids.each { |date_id| @attendees_hash[date_id] = { } }
    EventAttendee.find(:all, :conditions => ["event_date_id in (?)", event_date_ids]).each do |attendee|
      @attendees_hash[attendee.event_date_id][attendee.user_id] = attendee
    end
    
    @pages, @users = paginate(:user,
                              :per_page => per_page,
                              :conditions => conditions,
                              :order_by => "group_participations.id",
                              :include => [:user_uids, :group_participations, :user_profile,:event_owners, :event_attendees])
    
    @owner = false
    @owner = true if @event.event_owners.find_by_user_id(current_user.id)
  end
  
  def event_create
    @event = Event.new(params[:event])
    @event.acceptable = true
    @event.gid = @group.gid

    params[:date].each_with_index do |date, index|

      start_date = params["start_date_#{index}"].split("/")
      end_date = params["end_date_#{index}"].split("/")
      start_time = params[:date]["index_#{index}"]["start_time"].split(/:/)
      end_time = params[:date]["index_#{index}"]["end_time"].split(/:/)

      @event.event_dates.build(:start_time => EventDate.get_date_from_params(start_date,start_time), :end_time => EventDate.get_date_from_params(end_date,end_time), :fixed_date => false)
    end

    unless validate_params params, @event
      render :action => 'event_new'
      return
    end

    # 公開範囲
    @event.publication_symbol = params[:publication_type] == "public" ? "sid:allusers" : @group.symbol

    # 管理者(自分)
    @event.event_owners.build(:user_id => current_user.id)

    # @eventをsaveすることで、候補日、公開範囲、ユーザ、制約全部一緒にDBに入る
    if @event.save
      if @event.event_dates.size == 1 # 候補日がひとつなら確定日に指定する
        EventAttendee.create(:user_id => current_user.id,
                             :event_date_id => @event.event_dates.first.id,
                             :state => "attend",
                             :comment => "",
                             :group_participation_id => GroupParticipation.find_by_user_id_and_group_id(session[:user_id],@group.id).id)
      end

      redirect_to :action => 'event_show', :event_id => @event.id
      return
    else
      render :action => 'event_new'
    end
  end

  def event_update
    @event = Event.find(params[:event_id])
    if @event.update_attributes(params[:event])
      flash[:notice] = 'イベント情報の更新に成功しました。'
      redirect_to :action => 'event_show', :event_id => event.id
    else
      render :action => 'event_edit'
    end
  end

  def event_destroy
    event = Event.find(params[:event_id] )
    if event
      event.destroy
      flash[:notice] = 'イベントは削除されました。'
    else
      flash[:notice] = 'イベントの削除に失敗しました。'
    end
    redirect_to :action => 'event'
  end

  def event_close
    event = Event.find(params[:event_id])
    event.update_attributes(:acceptable => false)
    flash[:notice] = "締め切りました"
    redirect_to :action => "event_show", :event_id => event.id
  end

  # 締切解除（管理者のみ）
  def event_unclose
    event = Event.find(params[:event_id])
    event.update_attributes(:acceptable => true)
    flash[:notice] = "締め切りを解除しました"
    redirect_to :action => "event_show", :event_id => event.id
  end

  # キャンセル(締め切り後)
  def event_cancel
    change_attend_state(params[:user_id], params[:event_date_id], "absence",params[:event_id])

    flash[:notice] = "キャンセルしました。"
    redirect_to :action => "event_show", :event_id => params[:event_id]
  end

  # 管理者に設定する
  # ［操作可能］管理者のみ
  # params = { :user_id => xxx, :manager => true/false（管理者にするかどうか） }
  # success = 「管理者一覧画面」を表示
  # failure = もとの画面を表示
  def event_assign_user
    if event = Event.find_by_id(params[:event_id])
    if params[:owner] == "true"
      EventOwner.destroy_all(["event_id = ? and user_id = ?",event.id,params[:user_id]])
    else
      EventOwner.create(:event_id => event.id, :user_id => params[:user_id])
    end
    flash[:notice] = "管理者情報を変更しました。"
    end
    redirect_to :action => 'event_users', :event_id => event.id
  end
 
  def fix_date
    event = Event.find(params[:event_id])

    fixed_event_date = EventDate.find(params[:event_date_id]);

    if event_dates = EventDate.find_all_by_event_id(event.id)
    
      event_dates.each do |event_date|
        if event_date.id == params[:event_date_id].to_i
          event_date.update_attributes(:fixed_date => true )
        elsif event_date.fixed_date == true
          event_date.update_attributes(:fixed_date => false )
        end
      end

      # 開催日確定連絡(参加者あて)
      entry_params = { }
      entry_params[:title] ="【#{event.name}】開催日を確定しました"
      entry_params[:message] = "以下の日程でイベントを開催します。みなさんの参加をお待ちしています。"
      entry_params[:message] << BoardEntry::LINE_FEED
      entry_params[:message] << fixed_event_date.start_time.strftime("%Y/%m/%d %H:%M") + "～"
      entry_params[:message] << fixed_event_date.end_time.strftime("%Y/%m/%d %H:%M")
      entry_params[:message] << BoardEntry::LINE_FEED + "(出席連絡をされていない方はお早めに。)"
      entry_params[:tags] = "#{Tag::NOTICE_TAG},開催日確定"
      entry_params[:user_symbol] = session[:user_symbol]
      entry_params[:user_id] = session[:user_id]
      entry_params[:entry_type] = BoardEntry::GROUP_BBS
      entry_params[:owner_symbol] = @group.symbol
      entry_params[:publication_type] = 'private'
      entry_params[:publication_symbols] = [session[:user_symbol]]
      entry_params[:publication_symbols] << @group.symbol
      
      entry = BoardEntry.create_entry(entry_params)

      flash[:notice] = "確定しました"
    else
      flash[:notice] = "確定に失敗しました"
    end

    redirect_to :action => "event_show", :event_id => event.id
  end

  # 削除（管理者のみ）
  def delete_date
    event = Event.find(params[:event_id])
    EventDate.find(params[:event_date_id]).destroy
    event.save #eventのupdated_onを更新するためにeventをsaveする(キャッシュ生成用)
    flash[:notice] = "候補日を削除しました"
    redirect_to :action => "event_show", :event_id => event.id
  end

  # 出席
  def attend
    event_attendee = change_attend_state(params[:user_id], params[:event_date_id], "attend", params[:event_id])
    render_attendee(event_attendee, params[:only_icon])
  end

  # 欠席
  def absence
    event_attendee = change_attend_state(params[:user_id], params[:event_date_id], "absence", params[:event_id])
    render_attendee(event_attendee, params[:only_icon])
  end

  def ado_update_attendee_comment
    
    if params[:element_id]
      split_params = params[:element_id].split('_')
      participation_id ||= split_params[3]
      date_id ||= split_params[2]
    end
    attendee = EventAttendee.find_by_group_participation_id_and_event_date_id(participation_id, date_id)
    
    unless params[:comment]
      render :text => "　"
      return
    end

    if attendee
      attendee.update_attributes(:comment => params[:comment])
    else
      attendee = EventAttendee.create(:user_id => session[:user_id],
                                      :event_date_id => date_id,
                                      :group_participation_id => participation_id,
                                      :state => "pending",
                                      :comment => params[:comment])
    end

    # Inplaceエディタ内で直接ここで返した文字列を表示するためにHTMLエスケープする
    render :text => ERB::Util.html_escape(attendee.comment) || ""
  end

  # 候補日追加(管理者以外も可能)
  def append_date
    event = Event.find(params[:event][:id])

    start_date = params["start_date"].split("/")
    end_date = params["end_date"].split("/")
    start_time = params[:date]["start_time"].split(/:/)
    end_time = params[:date]["end_time"].split(/:/)

    validate_error = false

    unless EventDate.valid_date?(start_date,start_time) && EventDate.valid_date?(end_date,end_time)
      flash[:warning] = "候補日の追加を再度行ってください。(存在する日付を指定してください）"
      validate_error = true
    end

    event_start = EventDate.get_date_from_params(start_date,start_time)
    event_end = EventDate.get_date_from_params(end_date,end_time)

    # start、endの前後関係チェック
    if event_start >= event_end
      flash[:warning] = "候補日の追加を再度行ってください。(終了時刻は開始時刻以降の時間を設定してください）"
      validate_error = true
    end

    # まったく同じ候補日のチェック(DBを見る)
    if EventDate.find_by_event_id_and_start_time_and_end_time(event.id, event_start, event_end)

      flash[:warning] = "候補日の追加を再度行ってください。(すでに同じ候補日が存在します。追加する場合は他の日付を指定してください）"
      validate_error = true
    end

    unless validate_error
      event.event_dates.build(:start_time => event_start, :end_time => event_end, :fixed_date => false)
      event.save #eventのupdated_onを更新するために@eventをsaveする(キャッシュ生成用)
    end

    redirect_to :action => "event_show",:event_id => event.id

  end

private
  def setup_layout
    @main_menu = 'グループ'
    @title = @group.name if @group

    @tab_menu_source = []
    @tab_menu_source << ['サマリ', 'show']
    @tab_menu_source << ['参加者一覧', 'users']
    @tab_menu_source << ['掲示板', 'bbs']
    @tab_menu_source << ['新規投稿', 'new'] if participating?
    @tab_menu_source << ['ファイル', 'share_file']
    @tab_menu_source << ['管理', 'manage'] if participating? and @participation.owned?
    @tab_menu_source << ['イベント','event']
    @tab_menu_option = { :gid => @group.gid }

  end

  def load_group_and_participation
    unless @group = Group.find_by_gid(params[:gid])
      flash[:warning] = "指定のグループは存在していません"
      redirect_to :controller => 'mypage', :action => 'index'
      return false
    end
    @participation = @group.group_participations.find_by_user_id(session[:user_id])
  end

  def participating?
    @participation and @participation.waiting? != true
  end

  def check_owned
    unless @participation and @participation.owned?
      flash[:warning] = 'その操作は管理者権限が必要です。'
      redirect_to :controller => 'mypage', :action => 'index'
      return false
    end
  end


  def paginate_participations group, waiting
    return paginate(:group_participations,
                    :per_page => 20,
                    :conditions => ["group_participations.group_id = ? and group_participations.waiting = ?", group.id, waiting],
                    :include => :user)
  end

  def setup_bbs_left_box options
    find_params = BoardEntry.make_conditions(login_user_symbols, options)
    # 最近の投稿
    @recent_entries = BoardEntry.find(:all,
                                      :limit => 5,
                                      :conditions => find_params[:conditions],
                                      :include => find_params[:include],
                                      :order => "last_updated DESC,board_entries.id DESC")
    # カテゴリ
    @categories = BoardEntry.get_category_words(find_params)

    # 人毎のアーカイブ
    select_state = "count(distinct board_entries.id) as count, users.name as user_name, users.id as user_id"
    joins_state = "LEFT OUTER JOIN entry_publications ON entry_publications.board_entry_id = board_entries.id"
    joins_state << " LEFT OUTER JOIN users ON users.id = board_entries.user_id"
    find_params[:conditions].first << " and category not like '%[参加申し込み]%'"
    @user_archives = BoardEntry.find(:all,
                                     :select => select_state,
                                     :conditions=> find_params[:conditions],
                                     :group => "user_id",
                                     :order => "count desc",
                                     :joins => joins_state)
  end

###イベント関連

  # 出席欠席状況の変更
  def change_attend_state(user_id, event_date_id, state, event_id)
    @event = Event.find(event_id)
    if event_attendee = EventAttendee.find_by_user_id_and_event_date_id(user_id, event_date_id)
      event_attendee.update_attributes(:state => state) unless event_attendee.state == state
    else
      group = Group.find_by_gid(@event.gid) if @event.gid
      participation = GroupParticipation.find_by_user_id_and_group_id(user_id, group.id)
      event_attendee = EventAttendee.create(:user_id => user_id, :group_participation_id => participation.id, :event_date_id => event_date_id, :state => state, :comment => "")
    end
    return event_attendee
  end

  # 出席、欠席の後にrenderする
  def render_attendee(event_attendee, only_icon)
    if only_icon
      render :partial => 'attendee_icon', :locals => {:date => event_attendee.event_date, :attendee => event_attendee}
    else
      render :partial => 'attendee', :locals => {:event => @event, :date => event_attendee.event_date, :attendee => event_attendee}
    end
  end
  
  # 独自のバリデーション（成功ならtrue）
  def validate_params params, event
    # 公開範囲のタイプ
    unless %w(public private).include? params[:publication_type]
      event.errors.add_on_base "公開範囲の指定が不正です"
    end

    # 日付のフォーマットチェック
    index = 1
    last_join_dates = []
    params[:date].each_with_index do |date, index|

      start_date = params["start_date_#{index}"].split("/")
      end_date = params["end_date_#{index}"].split("/")
      start_time = params[:date]["index_#{index}"]["start_time"].split(/:/)
      end_time = params[:date]["index_#{index}"]["end_time"].split(/:/)

      if EventDate.valid_date?(start_date,start_time) && EventDate.valid_date?(end_date,end_time)
        event_start = EventDate.get_date_from_params(start_date,start_time)
        event_end = EventDate.get_date_from_params(end_date,end_time)

        date = EventDate.new(:start_time => event_start, :end_time => event_end )
        # 開始時刻は終了時刻以前か
        if date.start_time >= date.end_time
          event.errors.add("候補日(#{index + 1})の終了時刻", "は開始時刻以降の時間を設定してください")
        end
        # 同一の候補日を指定していないか
        if last_join_dates.include?(date.start_time.to_s + date.end_time.to_s)
          event.errors.add("", "同一の候補日が存在します")
        end
        last_join_dates << date.start_time.to_s + date.end_time.to_s
      else
        event.errors.add nil, "開催日/候補日#{index + 1}に指定した存在しない日付を変換しました"
      end
      index = index + 1
    end

    event.errors.empty?
  end

end
