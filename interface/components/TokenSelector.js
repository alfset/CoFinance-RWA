import { FormControl, InputLabel, Select, MenuItem } from "@mui/material";
import { supportedTokens, supportedSymbols } from "../utils/contracts";

export default function TokenSelector({ label, value, onChange, isSymbol }) {
  const options = isSymbol ? supportedSymbols : supportedTokens;
  return (
    <FormControl fullWidth>
      <InputLabel>{label}</InputLabel>
      <Select value={value} onChange={onChange}>
        {options.map((option) => (
          <MenuItem key={option} value={option}>
            {option}
          </MenuItem>
        ))}
      </Select>
    </FormControl>
  );
}