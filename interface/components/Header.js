"use client";

import { useState, useEffect } from "react";
import { AppBar, Toolbar, Button, Typography, Box, Snackbar, Alert } from "@mui/material";
import Link from "next/link";
import { connectWallet } from "../utils/web3"; 
import Swal from "sweetalert2";
import withReactContent from "sweetalert2-react-content";
import "@sweetalert2/theme-dark/dark.css";

const MySwal = withReactContent(Swal);

export default function Header({ setAccount }) {
  const [account, setLocalAccount] = useState(null);
  const [errorMessage, setErrorMessage] = useState(null);
  const [openSnackbar, setOpenSnackbar] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const restoreAccount = async () => {
      if (typeof window.ethereum !== "undefined") {
        try {
          const accounts = await window.ethereum.request({ method: "eth_accounts" });
          if (accounts.length > 0) {
            setLocalAccount(accounts[0]);
            setAccount(accounts[0]);
          }
        } catch (error) {
          console.warn("Auto-restore failed:", error);
        }
      }
    };

    restoreAccount();

    if (typeof window.ethereum !== "undefined") {
      window.ethereum.on("accountsChanged", (accounts) => {
        if (accounts.length > 0) {
          setLocalAccount(accounts[0]);
          setAccount(accounts[0]);
        } else {
          setLocalAccount(null);
          setAccount(null);
        }
      });

      window.ethereum.on("chainChanged", () => {
        restoreAccount();
      });

      return () => {
        window.ethereum.removeAllListeners("accountsChanged");
        window.ethereum.removeAllListeners("chainChanged");
      };
    }
  }, [setAccount]);

  const handleConnect = async () => {
    setLoading(true);
    try {
      const { address } = await connectWallet();
      setLocalAccount(address);
      setAccount(address);
      setErrorMessage(null);
      setOpenSnackbar(false);

      await MySwal.fire({
        icon: "success",
        title: "Wallet Connected",
        text: `Connected to: ${address}`,
      });
    } catch (error) {
      console.error("Wallet connection error:", error);
      const msg = error?.message || "Failed to connect wallet";
      setErrorMessage(msg);
      setOpenSnackbar(true);
    } finally {
      setLoading(false);
    }
  };


  const handleCloseSnackbar = (event, reason) => {
    if (reason === "clickaway") return;
    setOpenSnackbar(false);
  };

  return (
    <>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" sx={{ flexGrow: 1 }}>
            CoFInance RWA
          </Typography>
          <Box sx={{ display: "flex", gap: 2 }}>
            <Link href="/" passHref>
              <Button color="inherit">Home</Button>
            </Link>
            <Link href="/proof-of-assets" passHref>
              <Button color="inherit">Proof of Assets</Button>
            </Link>
            <Button color="inherit" onClick={handleConnect} disabled={loading}>
              {loading
                ? "Connecting..."
                : account
                ? `${account.slice(0, 6)}...${account.slice(-4)}`
                : "Connect Wallet"}
            </Button>
          </Box>
        </Toolbar>
      </AppBar>

      <Snackbar
        open={openSnackbar}
        autoHideDuration={6000}
        onClose={handleCloseSnackbar}
        anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
      >
        <Alert onClose={handleCloseSnackbar} severity="error" sx={{ width: "100%" }}>
          {errorMessage}
        </Alert>
      </Snackbar>
    </>
  );
}
