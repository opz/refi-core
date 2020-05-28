# ReFi Smart Contracts

[![Actions Status](https://github.com/opz/refi-core/workflows/CI/badge.svg)](https://github.com/opz/refi-core/actions)

## Install Dependencies

```
npm install
git submodule update --init --recursive
```

## Compile Contracts

`npx buidler compile`

## Run Tests

`npx buidler test`

## Run Solhint

`npm run lint`

## Run Code Coverage

`npx buidler coverage`

## Using ReFi smart contracts

To use ReFi smart contracts in a project, follow these steps:

```
git clone git@github.com:opz/refi-core.git
cd refi-core
npm install
git submodule update --init --recursive
npx buidler compile
npm link
cd <project_directory>
npm link refi-core
```

You can now import the smart contract artifacts in your project:
```
import ReFi from "refi-core/artifacts/ReFi.json";
```

## Contributors

* [@opz](https://github.com/opz) 💻
