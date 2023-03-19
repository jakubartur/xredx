package main

import (
    "encoding/json"
    "fmt"
    "io/ioutil"
)
type Genesis struct {
    Config       Config             `json:"config"`
    Nonce        string             `json:"nonce"`
    Timestamp    string             `json:"timestamp"`
    ExtraData    string             `json:"extraData"`
    GasLimit     string             `json:"gasLimit"`
    Difficulty   string             `json:"difficulty"`
    MixHash      string             `json:"mixHash"`
    Coinbase     string             `json:"coinbase"`
    Alloc        map[string]Account `json:"alloc"`
    Number       string             `json:"number"`
    GasUsed      string             `json:"gasUsed"`
    ParentHash   string             `json:"parentHash"`
    BaseFeePerGas *string            `json:"baseFeePerGas"`
}

type Config struct {
    ChainId           int    `json:"chainId"`
    HomesteadBlock    int    `json:"homesteadBlock"`
    EIP150Block       int    `json:"eip150Block"`
    EIP150Hash        string `json:"eip150Hash"`
    EIP155Block       int    `json:"eip155Block"`
    EIP158Block       int    `json:"eip158Block"`
    ByzantiumBlock    int    `json:"byzantiumBlock"`
    ConstantinopleBlock int  `json:"constantinopleBlock"`
    PetersburgBlock    int   `json:"petersburgBlock"`
    IstanbulBlock       int   `json:"istanbulBlock"`
    BerlinBlock         int   `json:"berlinBlock"`
    LondonBlock         int   `json:"londonBlock"`
    Ethash              struct{} `json:"ethash"`
}

type Account struct {
    Balance string `json:"balance"`
}
func loadGenesis(filename string) (*Genesis, error) {
    genesis := &Genesis{}

    data, err := ioutil.ReadFile(filename)
    if err != nil {
        return nil, fmt.Errorf("failed to read genesis file: %v", err)
    }

    err = json.Unmarshal(data, genesis)
    if err != nil {
        return nil, fmt.Errorf("failed to parse genesis file: %v", err)
    }

    return genesis, nil
}
func loadGenesis(filename string) (*Genesis, error) {
    genesis := &Genesis{}

    data, err := ioutil.ReadFile(filename)
    if err != nil {
        return nil, fmt.Errorf("failed to read genesis file: %v", err)
    }

    err = json.Unmarshal(data, genesis)
    if err != nil {
        return nil, fmt.Errorf("failed to parse genesis file: %v", err)
    }

    return genesis, nil
}
func main() {
    genesis, err := loadGenesis("genesis.json")
    if err != nil {
        panic(err)
    }

    fmt.Printf("%+v\n", genesis)
}
