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
    return tag("CloudVolume") if params[:pressed] == "cloud_volume_tag"
    delete_volumes if params[:pressed] == 'cloud_volume_delete'
    edit_record if params[:pressed] == 'cloud_volume_edit'
    form_button if params[:pressed] == 'form_button'

    if !@flash_array.nil? && params[:pressed] == "cloud_volume_delete" && @single_delete
      render :update do |page|
        # redirect to build the retire screen
        page.redirect_to :action => 'show_list', :flash_msg => @flash_array[0][:message]
      end
    elsif params[:pressed] == "cloud_volume_edit"
      if @flash_array
        show_list
        replace_gtl_main_div
      else
        if @redirect_controller
          render :update do |page|
            page.redirect_to :controller => @redirect_controller, :action => @refresh_partial, :id => @redirect_id, :org_controller => @org_controller
          end
        else
          render :update do |page|
            page.redirect_to :action => @refresh_partial, :id => @redirect_id
          end
        end
      end
    else
      if !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def get_form_vars
    @edit = @edit || {}
    @edit[:new] = @edit[:new] || {}
    @edit[:new][:name] = params[:name] if params[:name]
  end

  def set_form_vars
    @edit = {}
    @edit[:cloud_volume_id] = @volume.id
    @edit[:key] = "cloud_volume_edit__#{@volume.id || "new"}"
    @edit[:new] = {}
    @edit[:current] = {}
    @edit[:new][:name] = @volume.name
    @edit[:current] = @edit[:new].dup
    session[:edit] = @edit
  end

  # Set record variables to new values
  def set_record_vars(cloud_volume, mode = nil)
    cloud_volume.name = @edit[:new][:name]
    true
  end

  def valid_record?(cloud_volume)
    valid = true
    @errors = []
    valid
  end

  def new
    assert_privileges("cloud_volume_new")
    @volume = CloudVolume.new
    @in_a_form = true
    drop_breadcrumb(:name => "Add New #{ui_lookup(:table => 'cloud_volume')}", :url => "/cloud_volume/new")
  end

  def edit
    assert_privileges("cloud_volume_edit")
    @volume = find_by_id_filtered(CloudVolume, params[:id])
    set_form_vars
    @in_a_form = true
    session[:changed] = false
    drop_breadcrumb({:name => "Edit #{ui_lookup(:table => 'cloud_volume')} '#{@volume.name}'", :url => "/cloud_volume/edit/#{@volume.id}"})
  end

  def update
    assert_privileges("cloud_volume_edit")
    return unless load_edit("cloud_volume_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil
      flash = "Edit for Cloud Volume \""
      @breadcrumbs.pop if @breadcrumbs
      @volume = find_by_id_filtered(CloudVolume, params[:id])
      flash = _("Edit of #{ui_lookup(:table => 'cloud_volume')} \"#{@volume.name}\" was cancelled by the user")
      render :update do |page|
        page.redirect_to :action => @lastaction, :id => @volume.id, :display => session[:cloud_volume_display], :flash_msg => flash
      end

    when "save"
      valid_cloud_volume = find_by_id_filtered(CloudVolume, params[:id])
      set_record_vars(valid_cloud_volume)
      if valid_record?(valid_cloud_volume) && valid_cloud_volume.save
        add_flash(_("#{ui_lookup(:table => 'cloud_volume')} \"#{valid_cloud_volume.name}\" was saved"))
        @breadcrumbs.pop if @breadcrumbs
        AuditEvent.success(build_saved_audit(valid_cloud_volume, @edit))
        session[:edit] = nil
        session[:flash_msgs] = @flash_array.dup
        render :update do |page|
          page.redirect_to :action => "show", :id => valid_cloud_volume.id.to_s
        end
        return
      end

    when "reset"
      params[:edittype] = @edit[:edittype]
      add_flash(_("All changes have been reset"), :warning)
      @in_a_form = true
      session[:flash_msgs] = @flash_array.dup
      render :update do |page|
        page.redirect_to :action => 'edit', :id => params[:id]
      end

    when "validate"
      verify_cloud_volume = find_by_id_filtered(CloudVolume, params[:validate_id] ? params[:validate_id].to_i : params[:id])
      set_record_vars(verify_cloud_volume, :validate)
      @in_a_form = true
      @changed = session[:changed]
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    end
  end

  def form_field_changed
    return unless load_edit("cloud_volume_edit__#{params[:id]}")
    get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page.replace(@refresh_div, :partial => @refresh_partial) if @refresh_div
      page << javascript_for_miq_button_visibility(@changed) if @changed
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
    else
      volumes = [params[:id]]
    end

    if volumes.empty?
      add_flash(_("No #{ui_lookup(:tables => 'cloud_volumes')} were selected for deletion"), :error)
    end

    volumes_to_delete = []
    volumes.each do |v|
      volume = CloudVolume.find_by_id(v)
      if volume.nil?
        add_flash(_("#{ui_lookup(:table => "cloud_volume")} no longer exists."), :error)
      elsif volume.attachments.length > 0
        add_flash(_("\"#{volume.name}\": cannot be removed because it has attachments."), :warning)
      else
        volumes_to_delete.push(v)
      end
    end
    process_cloud_volumes(volumes_to_delete, "destroy") unless volumes_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif (@lastaction == "show" && @layout == "cloud_volume")
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %s was deleted") % ui_lookup(:table => "cloud_volume")) if @flash_array.nil?
    end
  end

  def process_cloud_volumes(volumes, task)
    return if volumes.empty?

    if task == "destroy"
      CloudVolume.find_all_by_id(volumes, :order => "lower(name)").each do |volume|
        audit = {
          :event => "cloud_volume_record_delete_initiateed",
          :message => "[#{volume.name}] Record delete initiated",
          :target_id => volume.id,
          :target_class => "CloudVolume",
          :userid => session[:userid]
        }
        AuditEvent.success(audit)
      end
      CloudVolume.destroy_queue(volumes)
      add_flash(
        "Delete initiated for #{pluralize(volumes.length, ui_lookup(:table => 'cloud_volume'))} from the CFME Database"
        )
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
