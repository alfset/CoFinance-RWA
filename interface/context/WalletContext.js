"use client";
import { createContext, useContext, useEffect, useState } from "react";
import { connectWallet } from "../utils/web3";

const WalletContext = createContext();

export const useWallet = () => useContext(WalletContext);

export default function WalletProvider({ children }) {
  const [account, setAccount] = useState(null);

  useEffect(() => {
    const checkAccount = async () => {
      if (typeof window.ethereum !== "undefined") {
        try {
          const accounts = await window.ethereum.request({ method: "eth_accounts" });
          if (accounts.length > 0) {
            setAccount(accounts[0]);
          }
        } catch (err) {
          console.error("Error checking wallet:", err);
        }
      }
    };

    checkAccount();

    window.ethereum?.on("accountsChanged", (accounts) => {
      setAccount(accounts.length > 0 ? accounts[0] : null);
    });

    return () => {
      window.ethereum?.removeAllListeners("accountsChanged");
    };
  }, []);

  return (
    <WalletContext.Provider value={{ account, setAccount }}>
      {children}
    </WalletContext.Provider>
  );
}
