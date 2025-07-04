import React from 'react';
import { Select, MenuItem, InputLabel, FormControl } from '@mui/material';
import { tokenAddresses } from '../utils/contracts';

const TokenSelector = ({ label, value, onChange, chain = 'sepolia' }) => {
  const options = Object.keys(tokenAddresses[chain] || {});

  return (
    <FormControl fullWidth margin="normal">
      <InputLabel>{label}</InputLabel>
      <Select
        value={value || ''}
        onChange={onChange}
        label={label}
      >
        {options.length > 0 ? (
          options.map((token) => (
            <MenuItem key={token} value={token}>
              {token}
            </MenuItem>
          ))
        ) : (
          <MenuItem value="" disabled>
            No tokens available
          </MenuItem>
        )}
      </Select>
    </FormControl>
  );
};

export default TokenSelector;