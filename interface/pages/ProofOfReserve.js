"use client";

import { useState, useEffect } from "react";
import {
  Container,
  Typography,
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  Box,
} from "@mui/material";
import styles from "../styles/Home.module.css";
import Header from "../components/Header";
import { ethers } from "ethers";
import {
  connectWallet,
  getContract,
  getTokenAddress,
  getTokenDecimals,
} from "../utils/web3";

export default function ProofOfReserve() {
  const [account, setAccount] = useState(null);
  const [balances, setBalances] = useState([]);
  const [isClient, setIsClient] = useState(false);
  const [error, setError] = useState(null);

  const chain = "avalancheFuji";
  const tokens = ["USDC", "WETH", "LINK", "WAVAX"];

  useEffect(() => {
    setIsClient(true);
    fetchBalances();
  }, [account]);

  const fetchBalances = async () => {
    try {
      if (!account) {
        const { signer, address } = await connectWallet(chain);
        if (!signer) {
          throw new Error("Failed to initialize signer");
        }
        setAccount(address);
      }

      const provider = new ethers.BrowserProvider(window.ethereum);
      const contract = await getContract("mintBurnManager", provider, chain);
      if (!contract || !contract.target) {
        throw new Error("Invalid contract address for mintBurnManager");
      }

      const balancePromises = tokens.map(async (token) => {
        const tokenAddress = getTokenAddress(chain, token);
        const decimals = await getTokenDecimals(chain, token);
        const balance = await contract.getContractTokenBalance(tokenAddress);
        return {
          token,
          balance: ethers.formatUnits(balance, decimals),
          decimals,
        };
      });

      const balanceData = await Promise.all(balancePromises);
      setBalances(balanceData);
      setError(null);
    } catch (error) {
      console.error("Error fetching balances:", {
        message: error.message,
        code: error.code,
        reason: error.reason,
        stack: error.stack,
      });
      setError(error.reason || error.message || "Failed to fetch token balances");
      setBalances([]);
    }
  };

  if (!isClient) {
    return null;
  }

  return (
    <div>
      <Header setAccount={setAccount} />
      <Container className={styles.container}>
        <Typography variant="h4" gutterBottom>
          Proof of Reserve
        </Typography>
        <Typography variant="body1" gutterBottom>
          Token balances held by the MintBurnManager contract on Avalanche Fuji.
        </Typography>
        {error && (
          <Typography color="error" gutterBottom>
            {error}
          </Typography>
        )}
        <TableContainer>
          <Table className={styles.recentTxTable}>
            <TableHead>
              <TableRow>
                <TableCell>Token</TableCell>
                <TableCell>Balance</TableCell>
                <TableCell>Decimals</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {balances.length > 0 ? (
                balances.map((item, index) => (
                  <TableRow key={index}>
                    <TableCell>{item.token}</TableCell>
                    <TableCell>{item.balance}</TableCell>
                    <TableCell>{item.decimals}</TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={3} align="center">
                    {error ? "Error loading balances" : "No balances available"}
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Container>
    </div>
  );
}
