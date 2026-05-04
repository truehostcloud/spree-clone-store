require 'spec_helper'

describe Spree::Olitt::CloneStore::CloneRequestProvisioner do
  describe '#call' do
    it 'provisions an admin user and links it to the vendor' do
      source_store = create(:store, default: false, url: 'source.example.com', code: 'source-store')
      clone_request = Spree::Olitt::CloneStore::CloneRequest.create!(
        source_store: source_store,
        store_name: 'Clone Store',
        store_url: 'clone.example.com',
        store_code: 'clone-store',
        store_mail_from_address: 'clone@example.com',
        vendor_email: 'vendor.clone@example.com',
        vendor_password: 'Password123!'
      )

      provisioner = described_class.new(clone_request: clone_request)

      expect(provisioner.call).to be(true)

      clone_request.reload
      expect(clone_request.admin_user).to be_present
      expect(clone_request.admin_user).to be_a(Spree.admin_user_class)
      expect(clone_request.admin_user.email).to eq('vendor.clone@example.com')
      expect(clone_request.admin_user.valid_password?('Password123!')).to be(true)
      expect(clone_request.vendor).to be_present
      expect(Spree::RoleUser.exists?(user: clone_request.admin_user, resource: clone_request.vendor)).to be(true)
      expect(Spree::VendorUser.exists?(vendor: clone_request.vendor, admin_user: clone_request.admin_user)).to be(true)
      expect(clone_request.store.vendor_id).to eq(clone_request.vendor.id)
    end
  end
end