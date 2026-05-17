// rule_id: effects/chains-of-computations
import { useEffect, useState } from 'react';

interface Card {
  gold: boolean;
}

export function Game() {
  const [card, setCard] = useState<Card | null>(null);
  const [goldCardCount, setGoldCardCount] = useState(0);
  const [round, setRound] = useState(1);
  const [isGameOver, setIsGameOver] = useState(false);

  useEffect(() => {
    if (card !== null && card.gold) {
      setGoldCardCount((c) => c + 1);
    }
  }, [card]);

  useEffect(() => {
    if (goldCardCount > 3) {
      setRound((r) => r + 1);
      setGoldCardCount(0);
    }
  }, [goldCardCount]);

  useEffect(() => {
    if (round > 5) {
      setIsGameOver(true);
    }
  }, [round]);

  return (
    <div>
      <p>Round {round}</p>
      <p>Gold cards: {goldCardCount}</p>
      {isGameOver && <p>Game over</p>}
      <button onClick={() => setCard({ gold: true })}>Play gold</button>
    </div>
  );
}
