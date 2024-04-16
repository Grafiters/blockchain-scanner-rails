class AddEncryptedField < ActiveRecord::Migration[5.2]
  def change
    add_column :wallets, :settings_encrypted, :string, limit: 1024, null: true
    add_column :payment_addresses, :secret_encrypted, :string, limit: 1024, null: true
    add_column :payment_addresses, :details_encrypted, :string, limit: 1024, null: true

    rename_column :wallets, :settings, :setting_wallet
    rename_column :payment_addresses, :secret, :secret_payment
    rename_column :payment_addresses, :details, :details_payment
  end
end
