import React, { useState, useEffect, useCallback } from 'react';
import { ConnectButton, useWalletKit } from '@mysten/wallet-kit';
import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import './OCWGame.css';

// Updated with the actual package ID from the deployment
const PACKAGE_ID = '0x94bda838ec981d1bb3f9b82c94c7417adc3a54d92bd35a23a601736a0e41898d';

// OCW coin type
const OCW_COIN_TYPE = `${PACKAGE_ID}::ocw::OCW`;

const provider = new SuiClient({ url: 'https://fullnode.testnet.sui.io' });

const OCWGame = () => {
  const [character, setCharacter] = useState(null);
  const [ocwBalance, setOcwBalance] = useState(0);
  const { currentAccount, signAndExecuteTransactionBlock } = useWalletKit();

  const fetchCharacter = useCallback(async () => {
    if (!currentAccount) return;
    try {
      const objects = await provider.getOwnedObjects({
        owner: currentAccount.address,
        filter: { StructType: `${PACKAGE_ID}::character::Character` },
        options: { showContent: true }
      });
      if (objects.data.length > 0) {
        const characterData = objects.data[0].data;
        setCharacter({
          id: characterData.objectId,
          level: characterData.content.fields.level,
          exp: characterData.content.fields.exp,
          maxHp: characterData.content.fields.max_hp,
          currentHp: characterData.content.fields.current_hp,
          isInjured: characterData.content.fields.is_injured,
        });
      } else {
        setCharacter(null);
      }
    } catch (e) {
      console.error("Error fetching character:", e);
    }
  }, [currentAccount]);

  const fetchOCWBalance = useCallback(async () => {
    if (!currentAccount) return;
    try {
      const balance = await provider.getBalance({
        owner: currentAccount.address,
        coinType: OCW_COIN_TYPE
      });
      setOcwBalance(balance.totalBalance);
    } catch (e) {
      console.error("Error fetching OCW balance:", e);
    }
  }, [currentAccount]);

  useEffect(() => {
    if (currentAccount) {
      fetchCharacter();
      fetchOCWBalance();
    } else {
      setCharacter(null);
      setOcwBalance(0);
    }
  }, [currentAccount, fetchCharacter, fetchOCWBalance]);

  const createCharacter = async () => {
    try {
      const tx = new TransactionBlock();
      const [newCharacter] = tx.moveCall({
        target: `${PACKAGE_ID}::character::new`,
        arguments: [],
      });
      tx.transferObjects([newCharacter], tx.pure(currentAccount.address));
      await signAndExecuteTransactionBlock({ transactionBlock: tx });
      await fetchCharacter();
    } catch (e) {
      console.error("Error creating character:", e);
    }
  };

const enterDungeon = async (level) => {
  if (!character) return;
  try {
    const tx = new TransactionBlock();
    const cost = [0, 100, 200, 300, 400][level - 1];

    if (cost > 0) {
      // Fetch the Coin<OCW> objects owned by the user
      const coins = await provider.getOwnedObjects({
        owner: currentAccount.address,
        filter: { StructType: OCW_COIN_TYPE },
      });

      if (coins.data.length === 0) {
        throw new Error("No OCW coins available for the transaction.");
      }

      // Use the first coin for payment
      const coinId = coins.data[0].data.objectId;

      tx.moveCall({
        target: `${PACKAGE_ID}::dungeons::enter_dungeon`,
        arguments: [
          tx.object(character.id),
          tx.pure(level),
          tx.object(coinId),
        ],
      });
    } else {
      // For free dungeon, pass a dummy coin ID
      tx.moveCall({
        target: `${PACKAGE_ID}::dungeons::enter_dungeon`,
        arguments: [
          tx.object(character.id),
          tx.pure(level),
          tx.object("0x0"), // Dummy coin ID for free dungeon
        ],
      });
    }

    await signAndExecuteTransactionBlock({ transactionBlock: tx });
    await fetchCharacter();
    await fetchOCWBalance();
  } catch (e) {
    console.error("Error entering dungeon:", e);
  }
};



  const completeDungeon = async (level) => {
    if (!character) return;
    try {
      const tx = new TransactionBlock();
      tx.moveCall({
        target: `${PACKAGE_ID}::dungeons::complete_dungeon`,
        arguments: [
          tx.object(character.id),
          tx.pure(level),
        ],
      });
      await signAndExecuteTransactionBlock({ transactionBlock: tx });
      await fetchCharacter();
      await fetchOCWBalance();
    } catch (e) {
      console.error("Error completing dungeon:", e);
    }
  };

  const healCharacter = async () => {
    if (!character) return;
    try {
      const tx = new TransactionBlock();
      const [coin] = tx.splitCoins(tx.gas, [tx.pure(10000)]);
      tx.moveCall({
        target: `${PACKAGE_ID}::main::heal_character`,
        arguments: [
          tx.object(character.id),
          coin,
        ],
      });
      await signAndExecuteTransactionBlock({ transactionBlock: tx });
      await fetchCharacter();
      await fetchOCWBalance();
    } catch (e) {
      console.error("Error healing character:", e);
    }
  };

  useEffect(() => {
    const countdownElement = document.getElementById('countdown');
    if (countdownElement) {
      const interval = setInterval(() => {
        let time = countdownElement.innerText.split(':').map(Number);
        let [hours, minutes, seconds] = time;

        if (seconds > 0) {
          seconds--;
        } else if (minutes > 0) {
          minutes--;
          seconds = 59;
        } else if (hours > 0) {
          hours--;
          minutes = 59;
          seconds = 59;
        }

        countdownElement.innerText = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
      }, 1000);

      return () => clearInterval(interval);
    }
  }, []);

  return (
    <div className="container">
      <h1 className="title">On-Chain Clan Wars Dashboard</h1>
      {!currentAccount ? (
        <ConnectButton />
      ) : (
        <div className="main-content">
          <div className="sidebar">
            <div className="card char-info">
              <div className="card-header">Character Info</div>
              {character ? (
                <>
                  <p><strong>Level:</strong> {character.level}</p>
                  <p><strong>EXP:</strong> {character.exp}</p>
                  <p><strong>HP:</strong> {character.currentHp}/{character.maxHp}</p>
                  <p><strong>Injured:</strong> {character.isInjured ? 'Yes' : 'No'}</p>
                  <p><strong>$OCW:</strong> {ocwBalance}</p>
                </>
              ) : (
                <button onClick={createCharacter} className="button">
                  Create Character
                </button>
              )}
            </div>

            <div className="card clan-info">
              <div className="card-header">Clan Info</div>
              <p><strong>Name:</strong> Dragon Slayers</p>
              <p><strong>Rank:</strong> 4</p>
              <p><strong>Power:</strong> 1800</p>
            </div>
          </div>

          <div className="dungeon-section">
            <div className="card">
              <div className="card-header">Dungeons</div>
              <div className="dungeon-grid">
                <div className="dungeon-card">
                  <h3>Novice</h3>
                  <p><strong>Success Rate:</strong> 100%</p>
                  <p><strong>EXP Gain:</strong> 100</p>
                  <p><strong>$OCW Earnings:</strong> 10</p>
                  <button className="button" onClick={() => enterDungeon(1)}>Enter Dungeon</button>
                </div>

                <div className="dungeon-card">
                  <h3>Adept</h3>
                  <p><strong>Success Rate:</strong> 70%</p>
                  <p><strong>EXP Gain:</strong> 250</p>
                  <p><strong>$OCW Earnings:</strong> 40</p>
                  <button className="button" onClick={() => enterDungeon(2)}>Enter Dungeon</button>
                </div>

                <div className="dungeon-card">
                  <h3>Expert</h3>
                  <p><strong>Success Rate:</strong> 50%</p>
                  <p><strong>EXP Gain:</strong> 450</p>
                  <p><strong>$OCW Earnings:</strong> 80</p>
                  <button className="button" onClick={() => enterDungeon(3)}>Enter Dungeon</button>
                </div>

                <div className="dungeon-card">
                  <h3>Master</h3>
                  <p><strong>Success Rate:</strong> 40%</p>
                  <p><strong>EXP Gain:</strong> 1000</p>
                  <p><strong>$OCW Earnings:</strong> 120</p>
                  <button className="button" onClick={() => enterDungeon(4)}>Enter Dungeon</button>
                </div>

                <div className="dungeon-card">
                  <h3>Legendary</h3>
                  <p><strong>Success Rate:</strong> 20%</p>
                  <p><strong>EXP Gain:</strong> 3000</p>
                  <p><strong>$OCW Earnings:</strong> 160</p>
                  <button className="button" onClick={() => enterDungeon(5)}>Enter Dungeon</button>
                </div>
              </div>
              <p id="dungeon-status">Select a dungeon to enter...</p>
            </div>

            <div className="bottom-row">
              <div className="card">
                <div className="card-header">Solo Raid</div>
                <button className="button" onClick={() => alert('Raid started!')}>Start Solo Raid</button>
              </div>

              <div className="card">
                <div className="card-header">Epoch War</div>
                <p>Next war: <span id="countdown">12:34:56</span></p>
                <div className="progress">
                  <div className="progress-bar"></div>
                </div>
              </div>

              <div className="card">
                <div className="card-header">Clan Management</div>
                <button className="button" onClick={() => alert('Redirecting to clan management page...')}>Manage Clan</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default OCWGame;

