
module Workers
    module Daemons
      class DepositAddress < Base
        self.sleep_time = 60
        def process
            Wallet.active.hot.all.each do |wallet|
                wallet_service = WalletService.new(wallet)
    
                PaymentAddress.where(wallet_id: wallet.id).each do |pa|
                    next if pa.address.present?
        
                    # Supply address ID in case of BitGo address generation if it exists.
                    details = {}
                    result = wallet_service.create_address!("-", details.merge(updated_at: pa.updated_at))
        
                    if result.present?
                      pa.update!(address: result[:address],
                                 secret:  result[:secret],
                                 details: result[:details])

                      pa.trigger_address_event
                    end
                end 
            end    
          rescue StandardError => e
            raise e if is_db_connection_error?(e)
    
            report_exception(e)
          end
      end
    end
end