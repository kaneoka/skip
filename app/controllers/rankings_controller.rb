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

class RankingsController < ApplicationController
  before_filter :setup_layout
  helper :calendar
# TODO 外部からのランキング取り込み機能は一旦ペンディングなのでコメントアウト
#  def update
#    new_ranking = Ranking.new params[:ranking]
#    exisiting_ranking = Ranking.find_by_url_and_extracted_on_and_contents_type(new_ranking.url, new_ranking.extracted_on, new_ranking.contents_type)
#    if exisiting_ranking.empty?
#      if new_ranking.save
#        head :created
#      else
#        head :bad_request
#      end
#    else
#      if exisiting_ranking.first.add_amount(new_ranking.amount)
#        head :ok
#      else
#        head :bad_request
#      end
#    end
#  end
  def index
    today = Date.today
    redirect_to monthly_path(:year => today.year, :month => today.month)
  end

  # GET /ranking_data/:content_type/:year/:month
  def data
    if params[:content_type].blank?
      return head(:bad_request)
    end

    if params[:year].blank?
      @rankings = Ranking.total(params[:content_type])
      return head(:not_found) if @rankings.empty?
    else
      return head(:bad_request) if params[:month].blank?
      begin
        Time.local(params[:year], params[:month])
        @rankings = Ranking.monthly(params[:content_type], params[:year], params[:month])
        return head(:not_found) if @rankings.empty?
      rescue => e
        return head(:bad_request)
      end
    end
    render :layout => false
  end

  def all
  end

  def monthly
    today = Date.today
    year = params[:year].blank? ? today.year : params[:year]
    month = params[:month].blank? ? today.month : params[:month]
    begin
      time = Time.local(year, month)
      @year = time.year
      @month = time.month
      @dates = (0..23).map { |i| today.ago(i.month).strftime('%Y-%m') }
    rescue => e
      flash.now[:error] = _('不正なパラメタです。')
      e.backtrace.each { |message| logger.error message }
      render :text => '', :status => :bad_request
    end
  end

  def statistics
    @date = Date.today
    if (params[:year] and params[:month] and params[:day])
      @date = Date.new(params[:year].to_i, params[:month].to_i, params[:day].to_i)
      @site_count = SiteCount.get_by_date(@date) || SiteCount.new
    else
      @site_count = SiteCount.find(:first, :order => "created_on desc") || SiteCount.new
    end
    flash[:notice] = _('対象データが見つかりません。') if @site_count.new_record?
    @item_count = get_site_count_hash_by_day @date
  end

  def load_calendar
    render :partial => "shared/calendar",
           :locals => { :sel_year => params[:year].to_i,
                        :sel_month => params[:month].to_i,
                        :sel_day => nil,
                        :item_count => get_site_count_hash_by_day(Date.new(params[:year].to_i, params[:month].to_i)),
                        :action => 'statistics'}
  end

  # ajax_action
  def ado_current_statistics
    date = Date.new(params[:year].to_i, params[:month].to_i, params[:day].to_i)
    site_count = SiteCount.find(:first,
                                :conditions => ["DATE_FORMAT(created_on, '%Y-%m-%d') = ?", date.strftime('%Y-%m-%d')]) || SiteCount.new #"
    render :partial => "current_statistics", :locals => { :site_count => site_count }
  end

  # ajax_action
  def ado_statistics_history
    date = Date.new(params[:year].to_i, params[:month].to_i)
    if params[:type] == "monthly"
      site_counts = SiteCount.find(:all,
                                   :conditions => ["DATE_FORMAT(created_on, '%Y-%m') = ?", date.strftime('%Y-%m')]) #"
      values = site_counts.map {|site_count| site_count[params[:category]] }
      max_value = values.max
      min_value = values.min
      render :partial => 'monthly_history',
             :locals => {:history_title => params[:desc],
                         :site_counts => site_counts,
                         :category => params[:category],
                         :date => date,
                         :max_value => max_value,
                         :min_value => min_value},
             :layout => false
    end
  end

  private
  def setup_layout
    @main_menu = @title = 'ランキング'

    @tab_menu_source = [ ['月別ランキング', 'monthly'],
                         ['総合ランキング', 'all'],
                         ['サイト情報', 'statistics'] ]
  end

  def get_site_count_hash_by_day date
    site_counts = SiteCount.find(:all,
                                 :conditions => ["DATE_FORMAT(created_on, '%Y-%m') = ?", date.strftime('%Y-%m')]) #"
    result = {}
    site_counts.each do |site_count|
      result[site_count.created_on.day] = 1
    end
    return result
  end
end