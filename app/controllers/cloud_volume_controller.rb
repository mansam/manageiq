class CloudVolumeController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

    @refresh_div = "main_div"
    tag("CloudVolume") if params[:pressed] == "cloud_volume_tag"
    delete_volumes if params[:pressed] == 'cloud_volume_delete'

    if !@flash_array.nil? && params[:pressed] == "cloud_volume_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg => @flash_array[0][:message]  # redirect to build the retire screen
      end
    else
      if !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @showtype = @display
    @lastaction = "show"

    @volume = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@volume)

    @gtl_url = "/cloud_volume/show/" << @volume.id.to_s << "?"
    drop_breadcrumb({:name => "Cloud Volumes", :url => "/cloud_volume/show_list?page=#{@current_page}&refresh=y"}, true)

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@volume)
      drop_breadcrumb(:name => @volume.name.to_s + " (Summary)", :url => "/cloud_volume/show/#{@volume.id}")
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    end

    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end


  # Show the main Cloud Volume list view
  def show_list
    process_show_list
  end

  def delete_volumes
    assert_privileges("cloud_volume_delete")
    volumes = []
    if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_volume")
      volumes = find_checked_items
      if volumes.empty?
        add_flash(
          _("No %{model} were selected for %{task}") % {
            :model => ui_lookup(:tables => "cloud_volumes"),
            :task => "deletion"
          },
          :error
        )
      end
      volumes_to_delete = []
      volumes.each do |v|
        volume = CloudVolume.find_by_id(v)
        if volume.attachments.length <= 0
          volumes_to_delete.push(v)
        else
          add_flash(_("\"%s\": cannot be removed because it has attachments.") % volume.name, :warning)
        end
      end
      process_cloud_volumes(volumes_to_delete, "destroy") unless volumes_to_delete.empty?
    else
      if params[:id].nil? || CloudVolume.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists.") % ui_lookup(:tables => "storage"), :error)
      else
        volumes.push(params[:id])
      end
      process_cloud_volumes(volumes, "destroy") unless volumes.empty?
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %s was deleted") % ui_lookup(:table => "cloud_volume")) if @flash_array.nil?
    end
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    end
  end

  def process_cloud_volumes(volumes, task)
    return if volumes.empty?

    if task == "destroy"
      CloudVolume.find_all_by_id(volumes, :order => "lower(name)").each do |volume|
        id = volume.id
        volume_name = volume.name
        audit = {
          :event => "cloud_volume_record_delete_initiateed",
          :message => "[#{volume_name}] Record delete initiated",
          :target_id => id,
          :target_class => "CloudVolume",
          :userid => session[:userid]
        }
        AuditEvent.success(audit)
      end
      #CloudVolume.destroy_queue(volumes)
      add_flash("Delete initiated for %{count_model} from the CFME Database" % {:count_model => pluralize(volumes.length, "cloud_volume")})
    end
  end

  private

  def get_session_data
    @title      = "Cloud Volume"
    @layout     = "cloud_volume"
    @lastaction = session[:cloud_volume_lastaction]
    @display    = session[:cloud_volume_display]
    @filters    = session[:cloud_volume_filters]
    @catinfo    = session[:cloud_volume_catinfo]
    @showtype   = session[:cloud_volume_showtype]
  end

  def set_session_data
    session[:cloud_volume_lastaction] = @lastaction
    session[:cloud_volume_display]    = @display unless @display.nil?
    session[:cloud_volume_filters]    = @filters
    session[:cloud_volume_catinfo]    = @catinfo
    session[:cloud_volume_showtype]   = @showtype
  end
end
