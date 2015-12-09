module CloudObjectStoreObjectHelper::TextualSummary

  def textual_group_properties
    %i(key content_type content_length last_modified etag)
  end

  def textual_group_relationships
    %i(ems cloud_tenant cloud_object_store_container)
  end

  def textual_group_tags
    %i(tags)
  end

  def textual_key
    @record.key
  end

  def textual_content_type
    @record.content_type
  end

  def textual_content_length
    {:label => "Content Length", :value => number_to_human_size(@record.content_length, :precision => 2)}
  end

  def textual_last_modified
    @record.last_modified
  end

  def textual_etag
    @record.etag
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenants")
    h = {:label => label, :image => "cloud_tenant", :value => (cloud_tenant.nil? ? "None" : cloud_tenant.name)}
    if cloud_tenant && role_allows(:feature => "cloud_tenant_show")
      h[:title] = "Show this Volume's #{label}"
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end

  def textual_cloud_object_store_container
    cloud_object_store_container = @record.cloud_object_store_container if @record.respond_to?(:cloud_object_store_container)
    label = ui_lookup(:table => "cloud_object_store_containers")
    h = {:label => label, :image => "cloud_object_store_container", :value => (cloud_object_store_container.nil? ? "None" : cloud_object_store_container.key)}
    if cloud_object_store_container && role_allows(:feature => "cloud_object_store_container_show")
      h[:title] = "Show this Object's #{label}"
      h[:link]  = url_for(:controller => 'cloud_object_store_container', :action => 'show', :id => cloud_object_store_container)
    end
    h
  end
end
