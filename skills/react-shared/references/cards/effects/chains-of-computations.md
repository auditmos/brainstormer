---
id: effects/chains-of-computations
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#chains-of-computations
---

# Chains of computations across multiple `useEffect`s

A component with several `useEffect`s where each watches a piece of state
and writes the next builds a cascade: setting state A re-renders, the
effect watching A fires and sets B, re-renders, the effect watching B fires
and sets C, re-renders. The component goes through N+1 commits to reach a
steady state that a single event handler could have produced in one update.

The cascade is also fragile — adding a fourth state at the head of the
chain quietly extends the cascade. Once the chain reaches three links it is
usually invisible to the author that the effects participate in a sequence
at all.

If the computation is driven by an event, do it in the handler that owns
the event. If it is driven by props, compute it during render or with
`useMemo`. Effects are for synchronizing with external systems, not for
chaining internal state updates.

## Detection

The pattern is semantic: two or more effects in the same component where
effect *B*'s dependency array includes a state variable that effect *A*'s
body sets via its setter. The judge must trace which setters write which
state, then see whether another effect in the same scope depends on that
state.

Trigger conditions to flag:

- The component declares ≥2 `useEffect` blocks.
- At least one effect's body calls a setter `setX(...)`.
- A subsequent effect's dependency array contains the same `X`.
- The chain could be expressed as a single event handler or a single
  derived expression in render.

## Bad

```tsx
function Game() {
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

  // ...
}
```

A single `setCard` ripples through three commits to reach `isGameOver`. The
sequence is invisible from any one effect's body.

## Good

```tsx
function Game() {
  const [card, setCard] = useState<Card | null>(null);
  const [goldCardCount, setGoldCardCount] = useState(0);
  const [round, setRound] = useState(1);
  const isGameOver = round > 5;

  function handlePlayCard(nextCard: Card) {
    if (isGameOver) {
      throw new Error('Game already ended.');
    }
    setCard(nextCard);
    if (nextCard.gold) {
      if (goldCardCount <= 3) {
        setGoldCardCount(goldCardCount + 1);
      } else {
        setGoldCardCount(0);
        setRound(round + 1);
      }
    }
  }
  // ...
}
```

One handler, one commit. `isGameOver` is now derived per render; no effect
participates in the state machine at all.

## Severity guidance

- **Friction** (default) — extra commits, no user-visible bug.
- **Blocker** — when any effect in the chain depends on a setter that may
  run in a stale closure (rare but real), the chain produces incorrect
  intermediate values; promote to Blocker. Always promote when the cascade
  sits in a render hot path (auth, payment, navigation).

## Citation

react.dev — [You Might Not Need an Effect — Chains of computations](https://react.dev/learn/you-might-not-need-an-effect#chains-of-computations).
