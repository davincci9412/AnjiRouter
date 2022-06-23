# AnjiRouter

## Deploy AnjiRouter

You will need to first create a *env.json* file 

*env.json*

- pkey: The Private key of the wallet
- bscScanApiKey: The API key on the https://bscscan.com/

```
{
    "pkey": "",
    "bscScanApiKey": ""
}
```

Run deploy:

`truffle migrate --network bsc --reset`
