import React from 'react';
import { Select, MenuItem, InputLabel, FormControl } from '@mui/material';

const SymbolSelector = ({ label, value, onChange }) => {
  const options = ["AAPL", "GOOG", "AMZN", "TSLA"];

  return (
    <FormControl fullWidth margin="normal">
      <InputLabel>{label}</InputLabel>
      <Select
        value={value || ''}
        onChange={onChange}
        disabled={options.length === 0}
        label={label}
      >
        {options.length > 0 ? (
          options.map((option) => (
            <MenuItem key={option} value={option}>
              {option}
            </MenuItem>
          ))
        ) : (
          <MenuItem disabled>No symbols available</MenuItem>
        )}
      </Select>
    </FormControl>
  );
};

export default SymbolSelector;