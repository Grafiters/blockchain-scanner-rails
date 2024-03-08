# =============> UPDATE LUMAYAN GEDEN LUR, SEGEDE RUANG DIPERUT <=============
## SETUP
penambahan pada `environment` atau `.env` yaitu
```
# untuk antrian rabbitmq
BLOCK_EXCHANGE_NAME
BLOCK_QUEUE_NAME
BLOCK_ROUTEING_KEY

# rpc connection ke masing - masing network !(ingat rpc connection itu berbeda dengan proxy)
RPC_BNB_NETWORK
RPC_TRON_NETWORK
```

## COMPOSE
untuk menjalankan worker tebaru silahkan pull repo dengan commit terbaru
```
  process_block:
    image: "oeypayblockchain:0.2"
    restart: always
    environment:
      - GROUP_ID=1
      - DATABASE_ADAPTER=postgresql
      - DATABASE_NAME=postgres
      - DATABASE_HOST=192.168.1.47
      - DATABASE_PORT=5432
      - DATABASE_USER=postgres
      - DATABASE_PASS=postgres
    command: bash -c "bundle exec ruby bin/block.rb"
    logging:
      driver: "json-file"
      options:
          max-size: "50m"
```

## PUBLISH TO CHANNEL
untuk publish to channel WAJIB HUKUMNYA menggunakan payload
```json
{
  tx_id: '0xcd443885266c80d101bbe6da84372981ed68de67a72eba41db320c13a649f9dd',
  block: 0,
  type: 'tx_id', (tx_id/block)
  blockchain_key: 'bnb-testnet' -> (blockchain)
}
```
dan dibuat string langsung (dalam testing menggunakan ruby hanya perlu `JSON.generate(generate_payload)` untuk yang lain belum menjajal) 
! HARAM HUKUMNYA ! jika mengubah variable payload, untuk publish sesuai dengan defined routing_key / exchange name / queque name pada `environment`

# Karena badan dan pikiran tidak optimal jadi untuk readme dibuat singkat saja
## Kebutuhan
untuk apa saja bisa dilihat di file ```.env_example```
  - RABBITMQ
  - DATABASE

## Cara menjalankan
1. cukup install docker `digoogle banyak caranya`
2. build image dengan command `docker build -t oeypayblockchain:0.2 .` atau terserah seleranya apa
3. sesuaikan image yang ada di `docker-compose.yml` dengan image yang telah kalian build
4. runn dengan command `docker-compose up -Vd blockchain_1 blockchain_2 deposit`
5. traraaaaa, worker sudah berjalan

# TERIMAKASIH