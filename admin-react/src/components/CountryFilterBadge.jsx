import React from 'react';
import { Chip, Box, Typography } from '@mui/material';
import { Public, Flag } from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter';

/**
 * Country Filter Badge - Shows current country scope in the header
 */
const CountryFilterBadge = () => {
  const { isSuperAdmin, getCountryDisplayName, userCountry } = useCountryFilter();

  const getCountryFlag = (country) => {
    const flags = {
      'lk': '🇱🇰',
      'in': '🇮🇳',
      'us': '🇺🇸',
      'uk': '🇬🇧',
      'ae': '🇦🇪'
    };
    return flags[country?.toLowerCase()] || '🌍';
  };

  return (
    <Box display="flex" alignItems="center" gap={1}>
      <Typography variant="caption" color="textSecondary">
        Viewing:
      </Typography>
      <Chip
        icon={isSuperAdmin ? <Public /> : <Flag />}
        label={
          <Box display="flex" alignItems="center" gap={0.5}>
            {!isSuperAdmin && <span>{getCountryFlag(userCountry)}</span>}
            <span>{getCountryDisplayName()}</span>
          </Box>
        }
        color={isSuperAdmin ? "primary" : "secondary"}
        variant={isSuperAdmin ? "filled" : "outlined"}
        size="small"
      />
    </Box>
  );
};

export default CountryFilterBadge;
