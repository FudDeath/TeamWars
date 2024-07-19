import React, { useState, useEffect, useCallback } from 'react';
import { ConnectButton, useWalletKit } from '@mysten/wallet-kit';
import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import './OCWGame.css';

// Updated constants
const PACKAGE_ID = '0xa8a3504af5ffd5b2526f93b59a1085839a3da66770529e39aa494b741b358cfd';
const OCW_COIN_TYPE = `${PACKAGE_ID}::ocw::OCW`;
const TREASURY_CAP_ID = '0xdd91946f21d64639de4ed890d08bcf854f810326636a8b32a189c578f745aca9';

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

  const mintOCW = async (amount) => {
    if (!currentAccount) return;
    try {
      const tx = new TransactionBlock();
      tx.moveCall({
        target: `${PACKAGE_ID}::ocw::mint`,
        arguments: [
          tx.object(TREASURY_CAP_ID),
          tx.pure(amount),
          tx.pure(currentAccount.address),
        ],
      });
      
      await signAndExecuteTransactionBlock({ transactionBlock: tx });
      await fetchOCWBalance();
    } catch (e) {
      console.error("Error minting OCW:", e);
    }
  };

const enterDungeon = async (level) => {
  if (!character) return;
  try {
    const cost = [0, 100, 200, 300, 400][level - 1] * 1000000; // Convert to OCW units
    const tx = new TransactionBlock();

    // Fetch the user's OCW coins
    const ocwCoins = await provider.getCoins({
      owner: currentAccount.address,
      coinType: OCW_COIN_TYPE,
    });

    if (ocwCoins.data.length === 0) {
      throw new Error("No OCW coins available for the transaction.");
    }
    
      console.log(`Found ${ocwCoins.data.length} OCW coins`);
      ocwCoins.data.forEach((coin, index) => {
      console.log(`Coin ${index}: ObjectID: ${coin.coinObjectId}, Balance: ${coin.balance}`);
      });

    // Use the first coin and split if necessary
    const [paymentCoin] = tx.splitCoins(tx.object(ocwCoins.data[0].coinObjectId), [tx.pure(cost)]);

    // Enter the dungeon with the OCW coins
    const [returnedCoin] = tx.moveCall({
      target: `${PACKAGE_ID}::dungeons::enter_dungeon`,
      arguments: [
        tx.object(character.id),
        tx.pure(level),
        paymentCoin,
      ],
    });

    // Transfer the returned coin back to the user
    tx.transferObjects([returnedCoin], tx.pure(currentAccount.address));

    // Execute the transaction
    const result = await signAndExecuteTransactionBlock({ transactionBlock: tx });
    console.log("Dungeon entry result:", result);
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
                  <p><strong>$OCW:</strong> {ocwBalance / 1000000}</p>
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
                {[
                  { level: 1, name: "Novice", color: "green" },
                  { level: 2, name: "Adept", color: "yellow" },
                  { level: 3, name: "Expert", color: "orange" },
                  { level: 4, name: "Master", color: "red" },
                  { level: 5, name: "Legendary", color: "purple" }
                ].map(dungeon => (
                  <div key={dungeon.level} className="dungeon-card">
                    <h3>{dungeon.name}</h3>
                    <p><strong>Success Rate:</strong> {100 - (dungeon.level - 1) * 20}%</p>
                    <p><strong>EXP Gain:</strong> {100 * Math.pow(2, dungeon.level - 1)}</p>
                    <p><strong>$OCW Cost:</strong> {(dungeon.level - 1) * 100}</p>
                    <button 
                      className={`button ${dungeon.color}`} 
                      onClick={() => enterDungeon(dungeon.level)}
                      disabled={!character}
                    >
                      Enter Dungeon
                    </button>
                  </div>
                ))}
              </div>
            </div>

            <div className="bottom-row">
              <div className="card">
                <div className="card-header">Complete Dungeon</div>
                <button 
                  className="button" 
                  onClick={() => completeDungeon(1)} 
                  disabled={!character}
                >
                  Complete Dungeon
                </button>
              </div>

              <div className="card">
                <div className="card-header">Heal Character</div>
                <button 
                  className="button" 
                  onClick={healCharacter} 
                  disabled={!character || !character.isInjured}
                >
                  Heal Character
                </button>
              </div>

              <div className="card">
                <div className="card-header">Mint OCW Tokens</div>
                <button className="button" onClick={() => mintOCW(150000000)}>
                  Mint 150 OCW
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default OCWGame;
