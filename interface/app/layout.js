import { CssBaseline } from "@mui/material";
import "../styles/globals.css";
import WalletProvider from "../context/WalletContext";

export const metadata = {
  title: "CoFInance RWA",
  description: "Mint and burn tokens on Avalanche",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <CssBaseline />
        <WalletProvider>
          {children}
        </WalletProvider>
      </body>
    </html>
  );
}
