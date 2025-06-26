"use client";

import React from "react";
import { FormControl, InputLabel, Select, MenuItem } from "@mui/material";

export default function ChainSelector({ value, onChange }) {
  return (
    <FormControl fullWidth margin="normal">
      <InputLabel id="chain-selector-label">Destination Chain</InputLabel>
      <Select
        labelId="chain-selector-label"
        value={value}
        label="Destination Chain"
        onChange={onChange}
      >
        <MenuItem value="avalancheFuji">Avalanche Fuji</MenuItem>
        <MenuItem value="sepolia">Sepolia</MenuItem>
      </Select>
    </FormControl>
  );
}
