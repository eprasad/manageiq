class Container < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  has_one    :container_group, :through => :container_definition
  has_one    :ext_management_system, :through => :container_group
  has_one    :container_replicator, :through => :container_group
  has_one    :container_project, :through => :container_group
  belongs_to :container_definition
  belongs_to :container_image
  has_one    :container_image_registry, :through => :container_image

  acts_as_miq_taggable
end
