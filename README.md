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