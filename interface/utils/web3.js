import { ethers } from "ethers";
import {
  contractAddresses,
  crossChainSenderABI,
  mintBurnManagerABI,
  mintingFunctionsConsumerABI,
} from "./contracts";

export const connectMetaMask = async () => {
  if (typeof window.ethereum === "undefined") {
    throw new Error("MetaMask is not installed");
  }

  try {
    const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
    if (!accounts.length) {
      throw new Error("wallet must has at least one account");
    }
    return accounts[0];
  } catch (error) {
    if (error.code === 4001) {
      throw new Error("Connection request was rejected by the user.");
    }
    throw error;
  }
};

export const switchChain = async (chainIdHex) => {
  if (!window.ethereum) throw new Error("MetaMask is not installed");

  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: chainIdHex }],
    });
  } catch (error) {
    if (error.code === 4902) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [
          {
            chainId: "0xa869",
            chainName: "Avalanche Fuji Testnet",
            nativeCurrency: { name: "AVAX", symbol: "AVAX", decimals: 18 },
            rpcUrls: ["https://api.avax-test.network/ext/bc/C/rpc"],
            blockExplorerUrls: ["https://testnet.snowtrace.io/"],
          },
        ],
      });
    } else {
      throw error;
    }
  }
};

export const connectWallet = async () => {
  const address = await connectMetaMask();
  const provider = new ethers.BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  await switchChain("0xa869");
  return { provider, signer, address };
};

export const getContract = (contractName, signer, chain = "avalancheFuji") => {
  const address = contractAddresses[chain]?.[contractName];
  if (!address || address.startsWith("0xYour")) {
    throw new Error(`Missing address for ${contractName} on ${chain}`);
  }

  const abis = {
    crossChainSender: crossChainSenderABI,
    mintBurnManager: mintBurnManagerABI,
    mintingFunctionsConsumer: mintingFunctionsConsumerABI,
  };

  const abi = abis[contractName];
  if (!abi) throw new Error(`Missing ABI for ${contractName}`);

  return new ethers.Contract(address, abi, signer);
};

export const getTokenDecimals = (symbol) => (symbol === "USDC" ? 6 : 18);
