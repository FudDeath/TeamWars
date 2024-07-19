import React from 'react';
import { WalletKitProvider } from '@mysten/wallet-kit';
import OCWGame from './OCWGame'; // Adjust the import path as necessary
import { Buffer } from 'buffer';

// Polyfill for the Buffer
window.Buffer = Buffer;

function App() {
  return (
    <WalletKitProvider>
      <OCWGame />
    </WalletKitProvider>
  );
}

export default App;
