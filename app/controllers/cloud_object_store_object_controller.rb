class CloudObjectStoreObjectController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def button
    @edit = session[:edit]
    params[:page] = @current_page unless @current_page.nil?
    return tag("CloudObjectStoreObject") if params[:pressed] = 'cloud_object_store_object_tag'
    render_button_partial(pfx)
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @showtype = @display
    @lastaction = "show"

    @object_store_object = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@object_store_object)

    @gtl_url = "/cloud_object_store_object/show" << @object_store_object.id.to_s << "?"
    drop_breadcrumb({:name => "Cloud Object Store Objects", :url => "/cloud_object_store_object/show_list?page=#{@current_page}&refresh=y"}, true)

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@object_store_object)
      drop_breadcrumb(:name => @object_store_object.key.to_s + " (Summary)", :url => "/cloud_object_store_object/show/#{@object_store_object.id}")
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    end

    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def show_list
    process_show_list
  end

  def render_button_partial(pfx)
    if @flash_array && params[:pressed] == "#{@table_name}_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg => @flash_array[0][:message]
      end
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                   "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def get_session_data
    @title      = "Cloud Object Store Object"
    @layout     = "cloud_object_store_object"
    @lastaction = session[:cloud_object_store_object_lastaction]
    @display    = session[:cloud_object_store_object_display]
    @filters    = session[:cloud_object_store_object_filters]
    @catinfo    = session[:cloud_object_store_object_catinfo]
    @showtype   = session[:cloud_object_store_object_showtype]
  end

  def set_session_data
    session[:cloud_object_store_object_lastaction] = @lastaction
    session[:cloud_object_store_object_display]    = @display unless @display.nil?
    session[:cloud_object_store_object_filters]    = @filters
    session[:cloud_object_store_object_catinfo]    = @catinfo
    session[:cloud_object_store_object_showtype]   = @showtype
  end

end
