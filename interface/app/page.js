"use client";

import { useState, useEffect } from "react";
import {
  Container,
  Typography,
  TextField,
  Button,
  Box,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Grid,
} from "@mui/material";
import styles from "../styles/Home.module.css";
import Header from "../components/Header";
import TokenSelector from "../components/TokenSelector";
import ChainSelector from "../components/ChainSelector";
import TransactionModal from "../components/TransactionModal";
import { getContract, connectWallet, getTokenDecimals } from "../utils/web3";
import { chainSelectors } from "../utils/contracts";
import { ethers } from "ethers";

export default function Home() {
  const [account, setAccount] = useState(null);
  const [symbolToMint, setSymbolToMint] = useState("AAPL");
  const [symbolForToken, setSymbolForToken] = useState("USDC");
  const [amount, setAmount] = useState("");
  const [destinationChain, setDestinationChain] = useState("avalancheFuji");
  const [modalOpen, setModalOpen] = useState(false);
  const [modalStatus, setModalStatus] = useState("");
  const [txHash, setTxHash] = useState("");
  const [qty, setQty] = useState(null);
  const [recentTxs, setRecentTxs] = useState([]);

  useEffect(() => {
    const handleUnhandledRejection = (event) => {
      const error = event.reason || {};
      console.error("Unhandled Promise Rejection:", {
        message: error.message || "Unknown error",
        code: error.code,
        reason: error.reason,
        data: error.data,
        stack: error.stack,
      });
      setModalStatus(`Error: ${error.reason || error.message || "Unhandled rejection occurred"}`);
      setModalOpen(true);
      event.preventDefault();
    };

    window.addEventListener("unhandledrejection", handleUnhandledRejection);
    return () => {
      window.removeEventListener("unhandledrejection", handleUnhandledRejection);
    };
  }, []);

  const addRecentTx = (type, symbol, amount, chain, status, txHash) => {
    setRecentTxs((prev) => [
      {
        type,
        symbol,
        amount,
        chain: chain || "N/A",
        status,
        txHash,
        timestamp: new Date().toLocaleString(),
      },
      ...prev.slice(0, 9),
    ]);
  };

  const handleMint = async () => {
    try {
      if (!amount || isNaN(amount) || Number(amount) <= 0) {
        throw new Error("Invalid amount");
      }
      const { signer } = await connectWallet();
      const contract = getContract("mintBurnManager", signer);
      const decimals = getTokenDecimals(symbolForToken);
      const parsedAmount = ethers.utils.parseUnits(amount, decimals);

      setModalStatus("Initiating Mint...");
      setModalOpen(true);

      const tx = await contract.initiateMint(symbolToMint, symbolForToken, parsedAmount);
      setTxHash(tx.hash);
      setModalStatus("Mint Transaction Submitted");
      addRecentTx("Mint", symbolToMint, amount, "avalancheFuji", "Submitted", tx.hash);

      await tx.wait();
      setModalStatus("Mint Initiated! Checking Result...");

      const consumerContract = getContract("mintingFunctionsConsumer", signer);
      let attempts = 0;
      while (attempts < 10) {
        const [requestId, , , lastQty] = await consumerContract.getLastResponse().catch((error) => {
          throw new Error(`Failed to get last response: ${error.message}`);
        });
        if (lastQty > 0) {
          const mintedQty = ethers.utils.formatUnits(lastQty, 18);
          setQty(mintedQty);
          setModalStatus(`Mint Successful! Quantity: ${mintedQty}`);
          addRecentTx("Mint", symbolToMint, amount, "avalancheFuji", "Successful", tx.hash);
          break;
        }
        await new Promise((resolve) => setTimeout(resolve, 3000));
        attempts++;
      }
      if (attempts === 10) {
        setModalStatus("Mint Initiated, but no result received yet.");
        addRecentTx("Mint", symbolToMint, amount, "avalancheFuji", "Pending Result", tx.hash);
      }
    } catch (error) {
      console.error("Mint error:", {
        message: error.message,
        code: error.code,
        reason: error.reason,
        data: error.data,
        stack: error.stack,
      });
      const errorMessage = error.reason || error.message || "Failed to initiate mint";
      setModalStatus(`Error: ${errorMessage}`);
      addRecentTx("Mint", symbolToMint, amount, "avalancheFuji", `Error: ${errorMessage}`, "");
    }
  };

  const handleCrossChainMint = async () => {
    try {
      if (!amount || isNaN(amount) || Number(amount) <= 0) {
        throw new Error("Invalid amount");
      }
      const { signer } = await connectWallet();
      const contract = getContract("crossChainSender", signer);
      const decimals = getTokenDecimals(symbolForToken);
      const parsedAmount = ethers.utils.parseUnits(amount, decimals);

      setModalStatus("Initiating Cross-Chain Mint...");
      setModalOpen(true);

      const tx = await contract.initiateCrossChainMint(symbolToMint, symbolForToken, parsedAmount);
      setTxHash(tx.hash);
      setModalStatus("Cross-Chain Transaction Submitted");
      addRecentTx("Cross-Chain Mint", symbolToMint, amount, destinationChain, "Submitted", tx.hash);

      await tx.wait();
      setModalStatus("Cross-Chain Mint Initiated! Checking Result...");

      const consumerContract = getContract("mintingFunctionsConsumer", signer);
      let attempts = 0;
      while (attempts < 10) {
        const [requestId, , , lastQty] = await consumerContract.getLastResponse().catch((error) => {
          throw new Error(`Failed to get last response: ${error.message}`);
        });
        if (lastQty > 0) {
          const mintedQty = ethers.utils.formatUnits(lastQty, 18);
          setQty(mintedQty);
          setModalStatus(`Cross-Chain Mint Successful! Quantity: ${mintedQty}`);
          addRecentTx("Cross-Chain Mint", symbolToMint, amount, destinationChain, "Successful", tx.hash);
          break;
        }
        await new Promise((resolve) => setTimeout(resolve, 3000));
        attempts++;
      }
      if (attempts === 10) {
        setModalStatus("Cross-Chain Mint Initiated, but no result received yet.");
        addRecentTx("Cross-Chain Mint", symbolToMint, amount, destinationChain, "Pending Result", tx.hash);
      }
    } catch (error) {
      console.error("Cross-Chain Mint error:", {
        message: error.message,
        code: error.code,
        reason: error.reason,
        data: error.data,
        stack: error.stack,
      });
      const errorMessage = error.reason || error.message || "Failed to initiate cross-chain mint";
      setModalStatus(`Error: ${errorMessage}`);
      addRecentTx("Cross-Chain Mint", symbolToMint, amount, destinationChain, `Error: ${errorMessage}`, "");
    }
  };

  const handleBurn = async () => {
    try {
      if (!amount || isNaN(amount) || Number(amount) <= 0) {
        throw new Error("Invalid amount");
      }
      const { signer } = await connectWallet();
      const contract = getContract("mintBurnManager", signer);
      const decimals = getTokenDecimals(symbolForToken);
      const parsedAmount = ethers.utils.parseUnits(amount, decimals);

      setModalStatus("Initiating Burn...");
      setModalOpen(true);

      const tx = await contract.initiateBurn(symbolToMint, symbolForToken, parsedAmount);
      setTxHash(tx.hash);
      setModalStatus("Burn Transaction Submitted");
      addRecentTx("Burn", symbolToMint, amount, "avalancheFuji", "Submitted", tx.hash);

      await tx.wait();
      setModalStatus("Burn Initiated Successfully!");
      setQty(null);
      addRecentTx("Burn", symbolToMint, amount, "avalancheFuji", "Successful", tx.hash);
    } catch (error) {
      console.error("Burn error:", {
        message: error.message,
        code: error.code,
        reason: error.reason,
        data: error.data,
        stack: error.stack,
      });
      const errorMessage = error.reason || error.message || "Failed to initiate burn";
      setModalStatus(`Error: ${errorMessage}`);
      addRecentTx("Burn", symbolToMint, amount, "avalancheFuji", `Error: ${errorMessage}`, "");
    }
  };

  const handleMintAction = () => {
    try {
      if (destinationChain === "avalancheFuji") {
        handleMint();
      } else if (destinationChain === "sepolia") {
        handleCrossChainMint();
      } else {
        throw new Error("Invalid destination chain selected");
      }
    } catch (error) {
      console.error("Mint action error:", {
        message: error.message,
        code: error.code,
        reason: error.reason,
        data: error.data,
        stack: error.stack,
      });
      const errorMessage = error.reason || error.message || "Failed to process mint action";
      setModalStatus(`Error: ${errorMessage}`);
      setModalOpen(true);
    }
  };

  return (
    <div>
      <Header setAccount={setAccount} />
      <Container className={styles.container}>
        <Grid container spacing={2}>
          <Grid item xs={12} md={8} order={{ xs: 1 }}>
            <Box className={styles.chartContainer}>
              <iframe
                src={`https://s.tradingview.com/widgetembed/?frameElementId=tradingview_widget&symbol=${symbolToMint}&interval=1&symboledit=0&saveimage=0&toolbarbg=f1f3f0&studies=[]&theme=light&style=1&timezone=Etc%2FUTC&studies_overrides={}&locale=en&utm_source=www.example.com&utm_medium=widget&utm_campaign=chart&utm_term=${symbolToMint}`}
                style={{ width: "100%", height: "100%", border: "none" }}
                title="TradingView Chart"
              ></iframe>
            </Box>
          </Grid>
          <Grid item xs={12} md={4} order={{ xs: 2 }}>
            <Box className={styles.formCard}>
              <Typography variant="h6" gutterBottom>
                Place Order
              </Typography>
              <Box className={styles.form}>
                <TokenSelector
                  label="Symbol"
                  value={symbolToMint}
                  onChange={(e) => setSymbolToMint(e.target.value)}
                  isSymbol
                />
                <TokenSelector
                  label="Payment Token"
                  value={symbolForToken}
                  onChange={(e) => setSymbolForToken(e.target.value)}
                />
                <TextField
                  label="Amount"
                  type="number"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  fullWidth
                />
                <ChainSelector
                  value={destinationChain}
                  onChange={(e) => setDestinationChain(e.target.value)}
                />
                <Button
                  variant="contained"
                  onClick={handleMintAction}
                  disabled={!account || !amount || !destinationChain}
                  className={`${styles.button} ${styles.primaryButton}`}
                >
                  {destinationChain === "avalancheFuji" ? "Buy (Mint)" : "Cross-Chain Mint"}
                </Button>
                <Button
                  variant="contained"
                  onClick={handleBurn}
                  disabled={!account || !amount}
                  className={`${styles.button} ${styles.secondaryButton}`}
                >
                  Sell (Burn)
                </Button>
              </Box>
            </Box>
          </Grid>
        </Grid>
        <Box className={styles.recentTxContainer}>
          <Typography variant="h6" gutterBottom>
            Recent Transactions
          </Typography>
          <TableContainer>
            <Table className={styles.recentTxTable}>
              <TableHead>
                <TableRow>
                  <TableCell>Type</TableCell>
                  <TableCell>Symbol</TableCell>
                  <TableCell>Amount</TableCell>
                  <TableCell>Chain</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell>Tx Hash</TableCell>
                  <TableCell>Timestamp</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {recentTxs.map((tx, index) => (
                  <TableRow key={index}>
                    <TableCell>{tx.type}</TableCell>
                    <TableCell>{tx.symbol}</TableCell>
                    <TableCell>{tx.amount}</TableCell>
                    <TableCell>{tx.chain}</TableCell>
                    <TableCell>{tx.status}</TableCell>
                    <TableCell>
                      {tx.txHash ? (
                        <a
                          href={`https://testnet.snowtrace.io/tx/${tx.txHash}`}
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          {tx.txHash.slice(0, 6)}...{tx.txHash.slice(-4)}
                        </a>
                      ) : "N/A"}
                    </TableCell>
                    <TableCell>{tx.timestamp}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </Box>
        <TransactionModal
          open={modalOpen}
          onClose={() => setModalOpen(false)}
          status={modalStatus}
          txHash={txHash}
          qty={qty}
        />
      </Container>
    </div>
  );
}