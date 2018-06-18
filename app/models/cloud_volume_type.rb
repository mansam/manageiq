class CloudVolumeType < ApplicationRecord

  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"

  acts_as_miq_taggable
end
