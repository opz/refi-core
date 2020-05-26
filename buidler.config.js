require("dotenv").config();

usePlugin("@nomiclabs/buidler-waffle");

function getEnv(env) {
  let value = process.env[env];

  if (typeof value == "undefined") {
    value = "";
    console.error(`WARNING: ${env} environment variable has not been set`);
  }

  return value;
}

const kovanEndpoint = getEnv("KOVAN_ENDPOINT");
const kovanMnemonic = getEnv("KOVAN_MNEMONIC");

module.exports = {
  networks: {
    kovan: {
      url: kovanEndpoint,
      chainId: 42,
      accounts: {
        mnemonic: kovanMnemonic
      }
    }
  },
  solc: {
    version: "0.6.8",
    optimizer: {
      enabled: true,
      runs: 999999
    }
  }
};
