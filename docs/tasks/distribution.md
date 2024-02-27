## How to process distribution for users

1. Create `csv` files with the following format

### Distribution table

  |      uid      | currency_code | amount |
  |---------------|-------------|--------|
  | ID1000003837  | usdt        |  100   |

  uid, currency_code, amount - required params

2. For process distribution
   
```ruby
   bundle exec rake distribution:process['file_name.csv']
```
