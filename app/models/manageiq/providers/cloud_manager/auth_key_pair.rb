class ManageIQ::Providers::CloudManager::AuthKeyPair < ::AuthPrivateKey
  include ReportableMixin
  acts_as_miq_taggable
  has_and_belongs_to_many :vms, :join_table => :key_pairs_vms, :foreign_key => :authentication_id
end
