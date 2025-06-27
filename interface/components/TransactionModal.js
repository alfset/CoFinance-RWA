import { Modal, Box, Typography, Button, Link } from "@mui/material";

const TransactionModal = ({ open, onClose, status, txHash, messageId, qty }) => {
  return (
    <Modal open={open} onClose={onClose}>
      <Box
        sx={{
          position: "absolute",
          top: "50%",
          left: "50%",
          transform: "translate(-50%, -50%)",
          width: 400,
          bgcolor: "background.paper",
          boxShadow: 24,
          p: 4,
          borderRadius: 2,
        }}
      >
        <Typography variant="h6" gutterBottom>
          Transaction Status
        </Typography>
        <Typography>{status}</Typography>
        {txHash && (
          <Typography sx={{ mt: 2 }}>
            {messageId ? "Message ID" : "Transaction Hash"}: <br />
            <Link
              href={
                messageId
                  ? `https://ccip.chain.link/msg/${messageId}`
                  : `https://${
                      status.includes("avalancheFuji") ? "testnet.snowtrace.io" : "sepolia.etherscan.io"
                    }/tx/${txHash}`
              }
              target="_blank"
              rel="noopener noreferrer"
            >
              {messageId ? `${messageId.slice(0, 6)}...${messageId.slice(-4)}` : `${txHash.slice(0, 6)}...${txHash.slice(-4)}`}
            </Link>
          </Typography>
        )}
        {qty && (
          <Typography sx={{ mt: 2 }}>
            Minted Quantity: {qty}
          </Typography>
        )}
        <Button onClick={onClose} variant="contained" sx={{ mt: 2 }}>
          Close
        </Button>
      </Box>
    </Modal>
  );
};

export default TransactionModal;