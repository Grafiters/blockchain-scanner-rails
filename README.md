# =============> UPDATE LUMAYAN GEDEN LUR, SEGEDE RUANG DIPERUT <=============
## ======> UPDATE <========
- [x] Init Project
- [x] Config Database
- [x] Configuration Schema Table
- [x] Configuration Scanning Block
  - [x] scanning single block
  - [x] scanning txid
- [x] Configuration Generate Address
- [x] Configuration endpoint blockchain
- [x] Deposit transaction
- [x] Wallet endpoint configuration
- [x] Withdraw transaction

# Karena badan dan pikiran tidak optimal jadi untuk readme dibuat singkat saja
## Kebutuhan
untuk apa saja bisa dilihat di file ```.env_example```
  - RABBITMQ
  - DATABASE

## Cara menjalankan
1. cukup install docker `digoogle banyak caranya`
2. build image dengan command `docker build -t gadai:0.1 .` atau terserah seleranya apa
3. sesuaikan image yang ada di `docker-compose.yml` dengan image yang telah kalian build
4. lengkapi configuration environment pada file compose tersebut untuk semua services
5. migrate the database `docker-compose run --rm backend bash -c "bundle exec rake db:create && bundle exec rake db:migrate && bundle exec rake db:seed"`
6. run dengan command `docker-compose up -Vd` maka seluruh services pada comopose dijalankan
7. traraaaaa, worker sudah berjalan

NOTE: -> { untuk endpoint list berada pada swaggerhub url `https://app.swaggerhub.com/apis/RYUDELTA7/gadai-endpoint/1.1.0#/` }


# SERVICES
- BACKEND -> endpoint services and can be comunicate with fronend or another service
- BLOCKCHAIN -> worker for schanning block
- DEPOSIT -> worker for doing transaction to collect value when send to internal address platform
- WITHDRAW -> worker for doing transaction to send value to external address
- CRON JOB -> worker for update wallet balance
- SCAN BLOCK -> worker for scan spesific block

## ENDPOINT
### BLOCKCHAIN ENDPOINT
this endpoint just for confguration about blockchain data and add some currencies but have to see the blockchain_key as registered before

## ACCOUNT
account endpoint just for configuration about address, deposit, and withdraw.

### /account/deposit_address/{currency}
but 1 endpoint on this group have a spesial treatment that is `/account/deposit_address/{currency}` cause some reason this endpoint will `Returns deposit address for account you want to deposit to by currency. The address may be blank because address generation process is still in progress. If this case you should try again later.`, generate address is using worker `deposit_addres` that file is on `deposit_coin_address` so to get runtime data has 2 option



1. subscribe on websocket `rango` and stream to this channel `private.deposit_address` that will send you updated data of this endpoint
```
{
  currencies: <string>
  blockchain_key: [string]
  address:  <string>
}
```
2. if you using queue progress on rabbitmq you can subcribe this channel `exchange_name=deposit_address` and `routing_key=deposit.global_address` that will give you updated address when progress generating is done the data for this is
```
{
  blockchain_key: <string>,
  currencies: [string],
  user_id: <string>,
  wallet_id: <int>,
  address: <string>
}
```

### DEPOSIT
about deposit will be update on queue rabbitmq with config `exchange_name=deposit` with `routing_key=deposit.process` that will send the data about progress deposit with this response data
```
{
  tid:                      <string>,
  user_id:                  <string>,
  currency:                 <string>,
  amount:                   <string>,
  state:                    <string>,
  wallet_state:             <string>,
  created_at:               time.iso8601,
  updated_at:               time.iso8601,
  completed_at:             time.iso8601,
  blockchain_address:       <string>,
  updated_state:            <timestamp>,
  blockchain_txid:          <string>
}
```

### WITHDRAW
withdraw is same like deposit proses but the configuration is using `exchange_name=withdraw_coin` with `routing_key=withdraw_coin_or_token` and will give you this response data
```
  { 
    tid:             <string>,
    user_id:         <string>,
    rid:             <string>,
    currency:        <string>,
    amount:          <string>,
    fee:             <string>,
    state:           <string>,
    created_at:      time.iso8601,
    updated_at:      time.iso8601,
    completed_at:    time.iso8601,
    blockchain_txid: <string>
  }
```

## WALLET
about the wallet endpoint group is for wallet platform config, the server url for wallet and blockchain can be difference

# TERIMAKASIH