"use client";

import { useState, useEffect } from "react";
import {
  Container,
  Typography,
  TextField,
  Button,
  Box,
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  Grid,
} from "@mui/material";
import styles from "../styles/Home.module.css";
import Header from "../components/Header";
import TokenSelector from "../components/TokenSelector";
import SymbolSelector from "../components/SymbolSelector";
import ChainSelector from "../components/ChainSelector";
import TransactionModal from "../components/TransactionModal";
import {
  getContract,
  connectWallet,
  getTokenDecimals,
  getTokenAddress,
  checkAndApproveToken,
  getMintBurnHandler,
} from "../utils/web3";
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
  const [messageId, setMessageId] = useState("");
  const [qty, setQty] = useState(null);
  const [recentTxs, setRecentTxs] = useState([]);
  const [isClient, setIsClient] = useState(false);

  useEffect(() => {
    setIsClient(true);
    setRecentTxs([]);
  }, []);

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

  const addRecentTx = (type, symbol, amount, chain, status, txHash, messageId = "") => {
    if (!isClient) return;
    setRecentTxs((prev) => [
      {
        type,
        symbol,
        amount,
        chain: chain || "N/A",
        status,
        txHash,
        messageId,
        timestamp: new Date().toISOString(),
      },
      ...prev.slice(0, 9),
    ]);
  };

  const handleMint = async () => {
    try {
      if (!amount || isNaN(amount) || Number(amount) <= 0) {
        throw new Error("Invalid amount");
      }

      setModalStatus("Please approve token spending in MetaMask...");
      setModalOpen(true);

      const { signer, address } = await connectWallet(destinationChain);
      if (!signer) {
        throw new Error(`Failed to initialize signer for ${destinationChain}`);
      }
      console.log("Signer Address:", address, "Chain:", destinationChain);
      setAccount(address);

      const decimals = await getTokenDecimals(destinationChain, symbolForToken);
      const parsedAmount = ethers.parseUnits(amount, decimals);
      const contract = await getContract("mintBurnManager", signer, destinationChain);
      console.log("MintBurnManager Contract:", contract, "Address:", contract?.target);

      if (!contract || !contract.target) {
        throw new Error(`Invalid contract address for mintBurnManager on ${destinationChain}`);
      }

      const { address: spenderAddress } = getMintBurnHandler(destinationChain);
      const tokenAddress = getTokenAddress(destinationChain, symbolForToken);
      if (!tokenAddress) {
        throw new Error(`Invalid token address for ${symbolForToken} on ${destinationChain}`);
      }

      await checkAndApproveToken(tokenAddress, spenderAddress, parsedAmount, signer);
      setModalStatus("Please sign the mint transaction in MetaMask...");
      const tx = await contract.initiateMint(symbolToMint, symbolForToken, parsedAmount);
      setTxHash(tx.hash);
      setModalStatus("Mint Transaction Submitted");
      addRecentTx("Mint", symbolToMint, amount, destinationChain, "Submitted", tx.hash);

      await tx.wait();
      setModalStatus("Mint Successful!");
      setQty(amount);
      addRecentTx("Mint", symbolToMint, amount, destinationChain, "Successful", tx.hash);
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
      addRecentTx("Mint", symbolToMint, amount, destinationChain, `Error: ${errorMessage}`, txHash || "");
    }
  };

  const handleCrossChainMint = async () => {
    try {
      if (!amount || isNaN(amount) || Number(amount) <= 0) {
        throw new Error("Invalid amount");
      }

      setModalStatus("Please approve token spending in MetaMask...");
      setModalOpen(true);

      const { signer, address } = await connectWallet(destinationChain);
      if (!signer) {
        throw new Error(`Failed to initialize signer for ${destinationChain}`);
      }
      console.log("Signer Address:", address, "Chain:", destinationChain);
      setAccount(address);

      const decimals = await getTokenDecimals(destinationChain, symbolForToken);
      const parsedAmount = ethers.parseUnits(amount, decimals);
      const contract = await getContract("crossChainSender", signer, destinationChain);
      console.log("CrossChainSender Contract:", contract, "Address:", contract?.target);
      if (!contract || !contract.target) {
        throw new Error(`Invalid contract address for crossChainSender on ${destinationChain}`);
      }

      const { address: spenderAddress } = getMintBurnHandler(destinationChain);
      const tokenAddress = getTokenAddress(destinationChain, symbolForToken);
      if (!tokenAddress) {
        throw new Error(`Invalid token address for ${symbolForToken} on ${destinationChain}`);
      }

      await checkAndApproveToken(tokenAddress, spenderAddress, parsedAmount, signer);
      setModalStatus("Please sign the cross-chain mint transaction in MetaMask...");
      const tx = await contract.initiateCrossChainMint(symbolToMint, symbolForToken, parsedAmount);
      const messageId = tx; 
      setTxHash(tx.hash);
      setMessageId(messageId);
      setModalStatus("Cross-Chain Transaction Submitted");
      addRecentTx("Cross-Chain Mint", symbolToMint, amount, destinationChain, "Submitted", tx.hash, messageId);

      await tx.wait();
      setModalStatus("Waiting for Finality...");
      addRecentTx("Cross-Chain Mint", symbolToMint, amount, destinationChain, "Waiting for Finality", tx.hash, messageId);

      setModalStatus("Cross-Chain Mint Successful!");
      setQty(amount);
      addRecentTx("Cross-Chain Mint", symbolToMint, amount, destinationChain, "Successful", tx.hash, messageId);
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
      addRecentTx("Cross-Chain Mint", symbolToMint, amount, destinationChain, `Error: ${errorMessage}`, txHash || "", messageId || "");
    }
  };

  const handleBurn = async () => {
    try {
      if (!amount || isNaN(amount) || Number(amount) <= 0) {
        throw new Error("Invalid amount");
      }

      if (destinationChain !== "avalancheFuji") {
        throw new Error("Burn operation is only supported on Avalanche Fuji");
      }

      setModalStatus("Please approve token spending in MetaMask...");
      setModalOpen(true);

      const { signer, address } = await connectWallet(destinationChain);
      if (!signer) {
        throw new Error(`Failed to initialize signer for ${destinationChain}`);
      }
      console.log("Signer Address:", address, "Chain:", destinationChain);
      setAccount(address);

      const decimals = await getTokenDecimals(destinationChain, symbolForToken);
      const parsedAmount = ethers.parseUnits(amount, decimals);
      const contract = await getContract("mintBurnManager", signer, destinationChain);
      console.log("MintBurnManager Contract:", contract, "Address:", contract?.target);
      if (!contract || !contract.target) {
        throw new Error(`Invalid contract address for mintBurnManager on ${destinationChain}`);
      }

      const { address: spenderAddress } = getMintBurnHandler(destinationChain);
      const tokenAddress = getTokenAddress(destinationChain, symbolForToken);
      if (!tokenAddress) {
        throw new Error(`Invalid token address for ${symbolForToken} on ${destinationChain}`);
      }

      await checkAndApproveToken(tokenAddress, spenderAddress, parsedAmount, signer);
      setModalStatus("Please sign the burn transaction in MetaMask...");
      const tx = await contract.initiateBurn(symbolToMint, symbolForToken, parsedAmount);
      setTxHash(tx.hash);
      setModalStatus("Burn Transaction Submitted");
      addRecentTx("Burn", symbolToMint, amount, destinationChain, "Submitted", tx.hash);

      await tx.wait();
      setModalStatus("Burn Initiated Successfully!");
      setQty(null);
      addRecentTx("Burn", symbolToMint, amount, destinationChain, "Successful", tx.hash);
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
      addRecentTx("Burn", symbolToMint, amount, destinationChain, `Error: ${errorMessage}`, txHash || "");
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

  if (!isClient) {
    return null;
  }

  return (
    <div>
      <Header setAccount={setAccount} />
      <Container className={styles.container}>
        <Grid container spacing={2}>
          <Grid item xs={12} md={8} order={{ xs: 1 }}>
            {isClient && (
              <Box className={styles.chartContainer}>
                <iframe
                  src={`https://s.tradingview.com/widgetembed/?frameElementId=tradingview_widget&symbol=${symbolToMint}&interval=1&symboledit=0&saveimage=0&toolbarbg=f1f3f0&studies=[]&theme=light&style=1&timezone=Etc%2FUTC&studies_overrides={}&locale=en&utm_source=www.example.com&utm_medium=widget&utm_campaign=chart&utm_term=${symbolToMint}`}
                  style={{ width: "100%", height: "100%", border: "none" }}
                  title="TradingView Chart"
                ></iframe>
              </Box>
            )}
          </Grid>
          <Grid item xs={12} md={4} order={{ xs: 2 }}>
            <Box className={styles.formCard}>
              <Typography variant="h6" gutterBottom>
                Place Order
              </Typography>
              <Box className={styles.form}>
                <SymbolSelector
                  label="Symbol"
                  value={symbolToMint}
                  onChange={(e) => setSymbolToMint(e.target.value)}
                />
                <TokenSelector
                  label="Payment Token"
                  value={symbolForToken}
                  onChange={(e) => setSymbolForToken(e.target.value)}
                  chain={destinationChain}
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
                  disabled={!account || !amount || !destinationChain || !symbolToMint || !symbolForToken}
                  className={`${styles.button} ${styles.primaryButton}`}
                >
                  {destinationChain === "avalancheFuji" ? "Buy (Mint)" : "Cross-Chain Mint"}
                </Button>
                <Button
                  variant="contained"
                  onClick={handleBurn}
                  disabled={!account || !amount || !symbolToMint || !symbolForToken || destinationChain !== "avalancheFuji"}
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
                  <TableCell>Tx Hash / Message ID</TableCell>
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
                      {tx.type === "Cross-Chain Mint" && tx.messageId ? (
                        <a
                          href={`https://ccip.chain.link/msg/${tx.messageId}`}
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          {tx.messageId.slice(0, 6)}...{tx.messageId.slice(-4)}
                        </a>
                      ) : tx.txHash ? (
                        <a
                          href={
                            tx.chain === "avalancheFuji"
                              ? `https://testnet.snowtrace.io/tx/${tx.txHash}`
                              : `https://sepolia.etherscan.io/tx/${tx.txHash}`
                          }
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          {tx.txHash.slice(0, 6)}...{tx.txHash.slice(-4)}
                        </a>
                      ) : (
                        "N/A"
                      )}
                    </TableCell>
                    <TableCell>
                      {tx.timestamp ? new Date(tx.timestamp).toLocaleString("en-US", { timeZone: "UTC" }) : "N/A"}
                    </TableCell>
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
          messageId={messageId}
          qty={qty}
        />
      </Container>
    </div>
  );
}