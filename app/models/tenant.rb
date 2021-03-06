require 'ancestry'

class Tenant < ActiveRecord::Base
  HARDCODED_LOGO = "custom_logo.png"
  HARDCODED_LOGIN_LOGO = "custom_login_logo.png"
  DEFAULT_URL = nil

  default_value_for :name,      "My Company"
  default_value_for :divisible, true
  has_ancestry

  has_many :owned_providers,              :foreign_key => :tenant_owner_id, :class_name => 'Provider'
  has_many :owned_ext_management_systems, :foreign_key => :tenant_owner_id, :class_name => 'ExtManagementSystem'
  has_many :owned_vm_or_templates,        :foreign_key => :tenant_owner_id, :class_name => 'VmOrTemplate'

  has_many :tenant_quotas
  has_many :miq_groups, :foreign_key => :tenant_owner_id
  has_many :users, :through => :miq_groups

  # FUTURE: /uploads/tenant/:id/logos/:basename.:extension # may want style
  has_attached_file :logo,
                    :url  => "/uploads/:basename.:extension",
                    :path => ":rails_root/public/uploads/:basename.:extension"

  has_attached_file :login_logo,
                    :url         => "/uploads/:basename.:extension",
                    :default_url => ":default_login_logo",
                    :path        => ":rails_root/public/uploads/:basename.:extension"

  validates :subdomain, :uniqueness => true, :allow_nil => true
  validates :domain,    :uniqueness => true, :allow_nil => true
  validate  :validate_only_one_root

  # FUTURE: allow more content_types
  validates_attachment_content_type :logo, :content_type => ['image/png']
  validates_attachment_content_type :login_logo, :content_type => ['image/png']

  scope :all_tenants,  -> { where(:divisible => true) }
  scope :all_projects, -> { where(:divisible => false) }

  virtual_column :parent_name, :type => :string

  before_save :nil_blanks

  def all_subtenants
    self.class.descendants_of(self).where(:divisible => true)
  end

  def all_subprojects
    self.class.descendants_of(self).where(:divisible => false)
  end

  def name
    tenant_attribute(:name, :company)
  end

  def parent_name
    parent.try(:name)
  end

  def login_text
    tenant_attribute(:login_text, :custom_login_text)
  end

  def logo_file_name
    tenant_attribute(:logo_file_name, :custom_logo) do |custom_logo|
      custom_logo && HARDCODED_LOGO
    end
  end

  def logo_content_type
    tenant_attribute(:logo_content_type, :custom_logo) do |_custom_logo|
      # fails validation when using custom_logo && "image/png"
      "image/png"
    end
  end

  def login_logo_file_name
    tenant_attribute(:login_logo_file_name, :custom_login_logo) do |custom_logo|
      custom_logo && HARDCODED_LOGIN_LOGO
    end
  end

  def login_logo_content_type
    tenant_attribute(:login_logo_content_type, :custom_login_logo) do |_custom_logo|
      # fails validation when using custom_logo && "image/png"
      "image/png"
    end
  end

  # @return [Boolean] Is this a default tenant?
  def default?
    subdomain == DEFAULT_URL && domain == DEFAULT_URL
  end

  def tenant?
    divisible?
  end

  def project?
    !divisible?
  end

  def logo?
    !!logo_file_name
  end

  def login_logo?
    !!login_logo_file_name
  end

  def self.default_tenant
    Tenant.find_by(:subdomain => DEFAULT_URL, :domain => DEFAULT_URL)
  end

  def self.root_tenant
    roots.first
  end

  def self.seed
    Tenant.find_by(:subdomain => DEFAULT_URL, :domain => DEFAULT_URL) ||
      Tenant.create(:subdomain => DEFAULT_URL, :domain => DEFAULT_URL).update_attributes(:name => nil)
  end

  private

  def tenant_attribute(attr_name, setting_name)
    ret = self[attr_name]
    # if the attribute is nil and we are the default tenant
    # then use settings values
    if ret.nil? && default?
      ret = settings.fetch_path(:server, setting_name)
      block_given? ? yield(ret) : ret
    else
      ret
    end
  end

  def nil_blanks
    self.subdomain = nil unless subdomain.present?
    self.domain = nil unless domain.present?

    self.name = nil unless name.present?
  end

  def settings
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end

  # validates that there is only one tree
  def validate_only_one_root
    if !(parent_id || parent)
      root = self.class.root_tenant
      errors.add(:parent, "required") if root && root != self
    end
  end
end
